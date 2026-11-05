#include "IconImageProvider.h"
#include <QPixmap>
#include <QFile>
#include <QUrl>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QtEndian>

IconImageProvider::IconImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

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

QImage IconImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    int s = requestedSize.isValid() ? qMax(requestedSize.width(), requestedSize.height()) : 32;
    QString decoded = QUrl::fromPercentEncoding(id.toUtf8());
    QString cleanId = decoded.section('?', 0, 0);

    if (cleanId.startsWith("sni:")) {
        QImage sniImg = fetchSniPixmap(cleanId);
        if (!sniImg.isNull()) {
            QImage scaled = sniImg.scaled(s, s, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            if (size) *size = scaled.size();
            return scaled;
        }
        cleanId = cleanId.contains("ayugram", Qt::CaseInsensitive) ? "com.ayugram.desktop" : "/home/whrr/.local/share/Throne/throne.png";
    }

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
    if (size) *size = pm.size();
    return pm.toImage();
}
