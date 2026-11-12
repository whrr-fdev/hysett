#include "MakoManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QDateTime>
#include <QDBusConnection>
#include <algorithm>

MakoManager::MakoManager(QObject *parent) : QObject(parent) {
    m_tickTimer = new QTimer(this);
    m_tickTimer->setInterval(200);
    connect(m_tickTimer, &QTimer::timeout, this, &MakoManager::onTickPopups);

    load();
    QProcess::execute("killall", {"-q", "mako"});
    registerDbusService();
    QTimer::singleShot(800, this, &MakoManager::registerDbusService);
}

void MakoManager::registerDbusService() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject("/org/freedesktop/Notifications", this, QDBusConnection::ExportScriptableSlots);
    bus.registerService("org.freedesktop.Notifications");
}

bool MakoManager::popupCritical() const {
    for (const auto &v : m_activePopups) {
        if (v.toMap()["critical"].toBool()) return true;
    }
    return false;
}

void MakoManager::onTickPopups() {
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    bool removed = false;
    for (int i = m_activePopups.size() - 1; i >= 0; --i) {
        QVariantMap m = m_activePopups[i].toMap();
        if (now >= m["expireAt"].toLongLong()) {
            m_activePopups.removeAt(i);
            m_history.prepend(m);
            while (m_history.size() > 50) m_history.removeLast();
            removed = true;
        }
    }
    if (m_activePopups.isEmpty()) m_tickTimer->stop();
    if (removed) emit popupChanged();
}

QStringList MakoManager::GetCapabilities() {
    return {"body", "body-markup", "icon-static", "persistence"};
}

QString MakoManager::GetServerInformation(QString &vendor, QString &version, QString &specVersion) {
    vendor = "whrr"; version = "2.0"; specVersion = "1.2";
    return "HySettNotificationDaemon";
}

uint MakoManager::Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                         const QString &summary, const QString &body, const QStringList &actions,
                         const QVariantMap &hints, int expire_timeout) {
    Q_UNUSED(actions);
    uint id = replaces_id > 0 ? replaces_id : m_nextId++;
    bool isCrit = (hints.contains("urgency") && hints["urgency"].toInt() == 2);
    QString ic = app_icon;
    if (ic.isEmpty()) {
        QString low = app_name.toLower();
        if (low.contains("ayugram")) ic = "com.ayugram.desktop";
        else if (low.contains("telegram")) ic = "org.telegram.desktop";
        else if (low.contains("firefox")) ic = "firefox";
    }
    showInternalNotification(app_name, summary, body, ic, isCrit, expire_timeout);
    return id;
}

void MakoManager::CloseNotification(uint id) {
    dismissPopup(int(id));
}

void MakoManager::showInternalNotification(const QString &appName, const QString &summary, const QString &body, const QString &icon, bool critical, int timeoutMs) {
    int id = int(m_nextId++);
    QString cleanBody = body;
    cleanBody.remove("<b>").remove("</b>").remove("<i>").remove("</i>");

    int dur = (timeoutMs > 0) ? timeoutMs : m_defaultTimeout;
    dur = std::clamp(dur, 1500, 15000);

    QVariantMap item;
    item["id"] = id;
    item["app"] = appName.isEmpty() ? "Система" : appName;
    item["summary"] = summary.isEmpty() ? item["app"].toString() : summary;
    item["body"] = cleanBody;
    item["icon"] = icon;
    item["critical"] = critical;
    item["time"] = QDateTime::currentDateTime().toString("hh:mm");
    item["expireAt"] = QDateTime::currentMSecsSinceEpoch() + dur;

    m_activePopups.prepend(item);
    while (m_activePopups.size() > 50) {
        m_history.prepend(m_activePopups.takeLast().toMap());
    }
    while (m_history.size() > 50) m_history.removeLast();

    if (!m_tickTimer->isActive()) m_tickTimer->start();
    emit popupChanged();
}

void MakoManager::dismissPopup(int id) {
    for (int i = 0; i < m_activePopups.size(); ++i) {
        if (m_activePopups[i].toMap()["id"].toInt() == id) {
            QVariantMap m = m_activePopups.takeAt(i).toMap();
            m_history.prepend(m);
            while (m_history.size() > 50) m_history.removeLast();
            emit popupChanged();
            return;
        }
    }
}

void MakoManager::dismissAll() {
    m_tickTimer->stop();
    for (int i = m_activePopups.size() - 1; i >= 0; --i) {
        m_history.prepend(m_activePopups[i].toMap());
    }
    while (m_history.size() > 50) m_history.removeLast();
    m_activePopups.clear();
    emit popupChanged();
}

void MakoManager::clearHistory() {
    m_history.clear();
    emit popupChanged();
}

void MakoManager::dismissHistoryItem(int id) {
    for (int i = 0; i < m_history.size(); ++i) {
        if (m_history[i].toMap()["id"].toInt() == id) {
            m_history.removeAt(i);
            emit popupChanged();
            return;
        }
    }
}

QString MakoManager::configPath() const { return QDir::homePath() + "/.config/mako/config"; }
QString MakoManager::formatHexRgba(const QColor &c, qreal alpha) const {
    int a = std::clamp(int(std::round(alpha * 255.0)), 0, 255);
    return QString("#%1%2%3%4").arg(c.red(), 2, 16, QChar('0')).arg(c.green(), 2, 16, QChar('0')).arg(c.blue(), 2, 16, QChar('0')).arg(a, 2, 16, QChar('0'));
}
void MakoManager::parseHexRgba(const QString &str, QColor &outCol, qreal &outAlpha) {
    QString s = str.trimmed();
    if (!s.startsWith('#')) return;
    if (s.length() == 9) {
        outCol = QColor(s.left(7));
        bool ok = false; int a = s.mid(7, 2).toInt(&ok, 16);
        if (ok) outAlpha = a / 255.0;
    } else if (s.length() == 7) outCol = QColor(s);
}
void MakoManager::load() {
    QFile f(configPath());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream in(&f);
    bool inCrit = false;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        if (line.startsWith('[')) { inCrit = (line.contains("critical") || line.contains("high")); continue; }
        int eq = line.indexOf('='); if (eq == -1) continue;
        QString k = line.left(eq).trimmed(), v = line.mid(eq + 1).trimmed();
        if (k == "anchor") m_anchor = v;
        else if (k == "width") m_width = std::clamp(v.toInt(), 220, 500);
        else if (k == "height") m_height = std::clamp(v.toInt(), 52, 96);
        else if (k == "margin") m_margin = std::clamp(v.split(',').first().toInt(), 0, 60);
        else if (k == "padding") m_padding = std::clamp(v.split(',').first().toInt(), 4, 24);
        else if (k == "border-size") m_borderSize = std::clamp(v.toInt(), 0, 10);
        else if (k == "border-radius") m_borderRadius = std::clamp(v.toInt(), 0, 30);
        else if (k == "default-timeout" && !inCrit) { int t = v.toInt(); m_defaultTimeout = (t <= 0) ? 4500 : std::clamp(t, 1000, 30000); }
        else if (k == "max-visible") m_maxVisible = std::clamp(v.toInt(), 1, 10);
        else if (k == "icons") m_icons = (v == "1" || v == "true");
        else if (k == "background-color") parseHexRgba(v, m_bgColor, m_bgOpacity);
        else if (k == "text-color") { qreal d = 1.0; parseHexRgba(v, m_textColor, d); }
        else if (k == "border-color") { qreal d = 1.0; if (inCrit) parseHexRgba(v, m_criticalBorderColor, d); else parseHexRgba(v, m_borderColor, d); }
    }
    f.close();
    emit changed();
}
void MakoManager::save() {
    QDir().mkpath(QDir::homePath() + "/.config/mako");
    QFile f(configPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&f);
        out << "font=JetBrainsMono NF " << m_fontSize << "\nanchor=" << m_anchor << "\nwidth=" << m_width << "\nheight=" << m_height << "\nmargin=" << m_margin << "\npadding=" << m_padding << "\nborder-size=" << m_borderSize << "\nborder-radius=" << m_borderRadius << "\ndefault-timeout=" << m_defaultTimeout << "\nmax-visible=" << m_maxVisible << "\nicons=" << (m_icons ? 1 : 0) << "\nbackground-color=" << formatHexRgba(m_bgColor, m_bgOpacity) << "\ntext-color=" << m_textColor.name(QColor::HexRgb) << "\nborder-color=" << formatHexRgba(m_borderColor, 0.85) << "\n\n[urgency=critical]\nborder-color=" << formatHexRgba(m_criticalBorderColor, 0.95) << "\n";
        f.close();
    }
}
void MakoManager::setAnchor(const QString &v) { if (m_anchor != v) { m_anchor = v; emit changed(); save(); } }
void MakoManager::setWidth(int v) { v = std::clamp(v, 220, 500); if (m_width != v) { m_width = v; emit changed(); save(); } }
void MakoManager::setHeight(int v) { v = std::clamp(v, 52, 96); if (m_height != v) { m_height = v; emit changed(); save(); } }
void MakoManager::setMargin(int v) { v = std::clamp(v, 0, 60); if (m_margin != v) { m_margin = v; emit changed(); save(); } }
void MakoManager::setPadding(int v) { v = std::clamp(v, 4, 24); if (m_padding != v) { m_padding = v; emit changed(); save(); } }
void MakoManager::setBorderSize(int v) { v = std::clamp(v, 0, 10); if (m_borderSize != v) { m_borderSize = v; emit changed(); save(); } }
void MakoManager::setBorderRadius(int v) { v = std::clamp(v, 0, 30); if (m_borderRadius != v) { m_borderRadius = v; emit changed(); save(); } }
void MakoManager::setFontSize(int v) { v = std::clamp(v, 8, 20); if (m_fontSize != v) { m_fontSize = v; emit changed(); save(); } }
void MakoManager::setDefaultTimeout(int v) { v = std::clamp(v, 1000, 30000); if (m_defaultTimeout != v) { m_defaultTimeout = v; emit changed(); save(); } }
void MakoManager::setMaxVisible(int v) { v = std::clamp(v, 1, 10); if (m_maxVisible != v) { m_maxVisible = v; emit changed(); emit popupChanged(); save(); } }
void MakoManager::setIcons(bool v) { if (m_icons != v) { m_icons = v; emit changed(); save(); } }
void MakoManager::setBgOpacity(qreal v) { v = std::clamp(v, 0.05, 1.0); if (!qFuzzyCompare(m_bgOpacity, v)) { m_bgOpacity = v; emit changed(); save(); } }
void MakoManager::setBgColor(const QColor &v) { if (v.isValid() && m_bgColor != v) { m_bgColor = v; emit changed(); save(); } }
void MakoManager::setTextColor(const QColor &v) { if (v.isValid() && m_textColor != v) { m_textColor = v; emit changed(); save(); } }
void MakoManager::setBorderColor(const QColor &v) { if (v.isValid() && m_borderColor != v) { m_borderColor = v; emit changed(); save(); } }
void MakoManager::setCriticalBorderColor(const QColor &v) { if (v.isValid() && m_criticalBorderColor != v) { m_criticalBorderColor = v; emit changed(); save(); } }
void MakoManager::sendTestNotification() { showInternalNotification("HySett", "Тестовое уведомление", "Компактное уведомление у правого края панели!", "com.whrr.HyprSettings", false); }
void MakoManager::sendCriticalNotification() { showInternalNotification("Система", "Важное уведомление!", "Проверка критического уведомления [urgency=critical]", "dialog-warning", true); }
void MakoManager::resetDefaults() { m_anchor = "top-right"; m_width = 320; m_height = 64; m_margin = 10; m_padding = 10; m_defaultTimeout = 4500; m_maxVisible = 4; emit changed(); save(); }

QVariantList MakoManager::activePopups() const {
    return m_activePopups.mid(0, m_maxVisible);
}

int MakoManager::hiddenPopupCount() const {
    return std::max(0, int(m_activePopups.size()) - m_maxVisible);
}
