#include <QHash>
#include "IconImageProvider.h"
#include <QPixmap>
#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QUrl>
#include <QColor>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QtEndian>
#include <algorithm>
#include <cmath>

IconImageProvider::IconImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

static QColor readCurrentThemeTint() {
    QString home = QDir::homePath();
    QFile st(home + "/.config/hypr/scripts/theme_state.conf");
    if (st.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (QString::fromUtf8(st.readAll()).trimmed() == "square") {
            return QColor("#ffffff");
        }
    }
    QFile cc(home + "/.config/hypr/scripts/control_center.conf");
    if (cc.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&cc);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith("accent_color=")) {
                QString hex = line.mid(13).trimmed();
                if (QColor::isValidColorName(hex)) return QColor(hex);
            }
        }
    }
    return QColor("#ffffff");
}

static QImage toMonochrome(const QImage &src, const QColor &tint) {
    if (src.isNull()) return src;
    QImage img = src.convertToFormat(QImage::Format_ARGB32);
    const int w = img.width();
    const int h = img.height();
    const int tr = tint.isValid() ? tint.red() : 255;
    const int tg = tint.isValid() ? tint.green() : 255;
    const int tb = tint.isValid() ? tint.blue() : 255;

    for (int y = 0; y < h; ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(img.scanLine(y));
        for (int x = 0; x < w; ++x) {
            QRgb px = line[x];
            int a = qAlpha(px);
            if (a == 0) continue;
            int lum = qGray(qRed(px), qGreen(px), qBlue(px));
            int r, g, b;
            if (lum > 185) {
                // Внутренний светлый символ (например, самолётик внутри кружка AyuGram) — делаем темным для четкого контраста
                r = std::clamp(int(tr * 0.16), 0, 255);
                g = std::clamp(int(tg * 0.16), 0, 255);
                b = std::clamp(int(tb * 0.16), 0, 255);
            } else {
                // Основной фон/кружок иконки — ярко окрашиваем в цвет темы!
                float boost = 0.50f + 0.12f * (float(lum) / 185.0f);
                r = std::clamp(int(std::round(tr * boost)), 0, 255);
                g = std::clamp(int(std::round(tg * boost)), 0, 255);
                b = std::clamp(int(std::round(tb * boost)), 0, 255);
            }
            line[x] = qRgba(r, g, b, a);
        }
    }
    return img;
}

static QImage fetchSniPixmap(const QString &serviceAndPath) {
    QString rest = serviceAndPath.mid(4);
    QString service = rest.section('|', 0, 0);
    QString path = rest.section('|', 1, 1);
    if (path.isEmpty()) path = "/StatusNotifierItem";

    QDBusMessage msg = QDBusMessage::createMethodCall(service, path, "org.freedesktop.DBus.Properties", "Get");
    msg << "org.kde.StatusNotifierItem" << "IconPixmap";
    QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 40);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) return {};

    QVariant v = reply.arguments().first().value<QDBusVariant>().variant();
    const QDBusArgument arg = v.value<QDBusArgument>();
    if (arg.currentType() != QDBusArgument::ArrayType) return {};

    QImage bestImg;
    int bestW = 0;
    arg.beginArray();
    while (!arg.atEnd()) {
        int w = 0, h = 0;
        QByteArray data;
        arg.beginStructure();
        arg >> w >> h >> data;
        arg.endStructure();
        if (w > bestW && w <= 128 && data.size() >= w * h * 4) {
            QImage img(w, h, QImage::Format_ARGB32);
            const uchar *src = reinterpret_cast<const uchar*>(data.constData());
            for (int y = 0; y < h; ++y) {
                QRgb *dst = reinterpret_cast<QRgb*>(img.scanLine(y));
                for (int x = 0; x < w; ++x) {
                    dst[x] = qFromBigEndian<uint32_t>(src + (y * w + x) * 4);
                }
            }
            bestImg = img;
            bestW = w;
        }
    }
    arg.endArray();
    return bestImg;
}

static QString resolveIconFilePath(const QString &nameOrPath) {
    if (nameOrPath.startsWith('/') && QFile::exists(nameOrPath)) return nameOrPath;
    const QStringList dirs = {
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/128x128/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/hicolor/32x32/apps/",
        "/usr/share/pixmaps/"
    };
    for (const QString &d : dirs) {
        if (QFile::exists(d + nameOrPath + ".png")) return d + nameOrPath + ".png";
        if (QFile::exists(d + nameOrPath + ".svg")) return d + nameOrPath + ".svg";
    }
    return nameOrPath;
}

QImage IconImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    int s = requestedSize.isValid() ? qMax(requestedSize.width(), requestedSize.height()) : 32;
    QString decoded = QUrl::fromPercentEncoding(id.toUtf8());
    bool mono = false;
    if (decoded.startsWith("mono:")) {
        mono = true;
        decoded = decoded.mid(5);
    }

    QColor tintColor = mono ? readCurrentThemeTint() : QColor("#ffffff");
    int tintIdx = decoded.lastIndexOf("tint=");
    if (tintIdx != -1) {
        QString hex = decoded.mid(tintIdx + 5, 6).trimmed();
        if (!hex.startsWith('#')) hex.prepend('#');
        if (QColor::isValidColorName(hex)) tintColor = QColor(hex);
    }

    QString cleanId = decoded.section('?', 0, 0);

    if (cleanId.startsWith("sni:")) {
        QString fallbackPart = cleanId.section('|', 2, 2);
        static QHash<QString, QImage> s_sniPixmapCache;
        QImage sniImg = s_sniPixmapCache.value(cleanId);
        if (sniImg.isNull()) {
            sniImg = fetchSniPixmap(cleanId);
            if (!sniImg.isNull()) s_sniPixmapCache.insert(cleanId, sniImg);
        }
        if (!sniImg.isNull()) {
            QImage scaled = sniImg.scaled(s, s, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            if (mono) scaled = toMonochrome(scaled, tintColor);
            if (size) *size = scaled.size();
            return scaled;
        }
        if (!fallbackPart.isEmpty()) {
            cleanId = fallbackPart;
        } else {
            cleanId = cleanId.contains("ayugram", Qt::CaseInsensitive) ? "com.ayugram.desktop" : "/home/whrr/.local/share/Throne/throne.png";
        }
    }

    cleanId = resolveIconFilePath(cleanId);

    QPixmap pm;
    if (cleanId.startsWith('/') && QFile::exists(cleanId)) {
        pm = QPixmap(cleanId).scaled(s, s, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    } else {
        QIcon icon = QIcon::fromTheme(cleanId);
        if (icon.isNull()) icon = QIcon::fromTheme(cleanId.toLower());
        if (icon.isNull()) icon = QIcon::fromTheme("application-x-executable");
        pm = icon.pixmap(s, s);
    }
    if (pm.isNull()) {
        pm = QPixmap(s, s);
        pm.fill(Qt::transparent);
    }
    QImage out = pm.toImage();
    if (mono) out = toMonochrome(out, tintColor);
    if (size) *size = out.size();
    return out;
}
