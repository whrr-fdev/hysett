#include <QRegularExpression>
#include "DevicesManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <algorithm>

static bool jsonToBool(const QJsonValue &v) {
    if (v.isBool()) return v.toBool();
    if (v.isDouble()) return v.toInt() != 0;
    if (v.isString()) {
        QString s = v.toString().trimmed().toLower();
        return s == "1" || s == "true" || s == "yes";
    }
    return false;
}

static qint64 jsonToBytes(const QJsonValue &v) {
    if (v.isDouble()) return static_cast<qint64>(v.toDouble());
    if (v.isString()) return v.toString().trimmed().toLongLong();
    return 0;
}

static QString formatDriveSize(qint64 bytes) {
    if (bytes <= 0) return "";
    double gb = bytes / (1024.0 * 1024.0 * 1024.0);
    if (gb >= 1.0) return QString("%1 GB").arg(gb, 0, 'f', gb >= 10.0 ? 0 : 1);
    double mb = bytes / (1024.0 * 1024.0);
    return QString("%1 MB").arg(std::max(1.0, mb), 0, 'f', 0);
}

DevicesManager::DevicesManager(QObject *parent) : QObject(parent) {
    checkTouchpad();
    loadSettings();
    refreshUsbDrives();

    m_usbPollTimer = new QTimer(this);
    m_usbPollTimer->setInterval(2000);
    connect(m_usbPollTimer, &QTimer::timeout, this, &DevicesManager::pollUsbSignature);
    m_usbPollTimer->start();
}

void DevicesManager::pollUsbSignature() {
    QByteArray sig;
    QFile fp("/proc/partitions");
    if (fp.open(QIODevice::ReadOnly)) {
        sig += fp.readAll();
        fp.close();
    }
    QFile fm("/proc/mounts");
    if (fm.open(QIODevice::ReadOnly)) {
        const QByteArray lines = fm.readAll();
        for (const QByteArray &ln : lines.split('\n')) {
            if (ln.startsWith("/dev/sd") || ln.startsWith("/dev/nvme") || ln.startsWith("/dev/mmc") || ln.contains("/run/media") || ln.contains("/mnt")) {
                sig += ln + "\n";
            }
        }
        fm.close();
    }
    if (sig != m_lastPartitionsSig) {
        m_lastPartitionsSig = sig;
        refreshUsbDrives();
    }
}

static bool isSystemMountPoint(const QString &mp) {
    if (mp == "/" || mp == "/boot" || mp == "/boot/efi" || mp == "/home" || mp == "[SWAP]") return true;
    return false;
}

static bool isVentoyOrBootHelperPartition(const QJsonObject &part, qint64 partBytes, qint64 maxDiskPartBytes, int siblingCount) {
    QString label = part["label"].toString().trimmed().toUpper();
    QString partLabel = part["partlabel"].toString().trimmed().toUpper();
    if (label == "VTOYEFI" || partLabel == "VTOYEFI" ||
        label == "UEFI_NTFS" || partLabel == "UEFI_NTFS" ||
        label == "MISO_EFI" || partLabel == "MISO_EFI") {
        return true;
    }
    // Если на флешке несколько разделов и один из них <= 64 МБ (служебный EFI-раздел Ventoy/Rufus), скрываем его
    if (siblingCount > 1 && partBytes > 0 && partBytes <= 68LL * 1024 * 1024 && maxDiskPartBytes > 256LL * 1024 * 1024) {
        return true;
    }
    return false;
}

void DevicesManager::refreshUsbDrives() {
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        QByteArray out = p->readAllStandardOutput();
        p->deleteLater();

        QJsonObject rootObj = QJsonDocument::fromJson(out).object();
        QJsonArray blockdevs = rootObj["blockdevices"].toArray();
        QVariantList result;

        auto parsePartObj = [&](const QJsonObject &part, const QString &diskModel, const QString &diskVendor, bool diskRemovable, qint64 maxPartBytes, int siblingCount) {
            QString name = part["name"].toString().trimmed();
            if (name.isEmpty() || name.startsWith("zram") || name.startsWith("loop") || name.startsWith("sr")) return;
            QString devPath = part["path"].toString().trimmed();
            if (devPath.isEmpty()) devPath = "/dev/" + name;

            qint64 szBytes = jsonToBytes(part["size"]);
            if (szBytes > 0 && szBytes <= 65536) return; // пропускаем контейнер расширенного раздела

            QString fstype = part["fstype"].toString().trimmed();
            if (fstype.toLower() == "swap") return;

            QString mp = part["mountpoint"].toString().trimmed();
            if (mp.isEmpty() && part.contains("mountpoints")) {
                QJsonArray mps = part["mountpoints"].toArray();
                for (const QJsonValue &v : mps) {
                    if (!v.isNull() && !v.toString().trimmed().isEmpty()) {
                        mp = v.toString().trimmed();
                        break;
                    }
                }
            }
            if (isSystemMountPoint(mp)) return;

            bool isRm = jsonToBool(part["rm"]) || jsonToBool(part["hotplug"]) || diskRemovable;
            if (!isRm && !mp.startsWith("/run/media/") && !mp.startsWith("/media/")) return;

            // Отфильтровываем служебный раздел VTOYEFI у флешек с Ventoy
            if (isVentoyOrBootHelperPartition(part, szBytes, maxPartBytes, siblingCount)) return;

            QString label = part["label"].toString().trimmed();
            QString partLabel = part["partlabel"].toString().trimmed();
            QString displayTitle = label;
            if (displayTitle.isEmpty()) displayTitle = partLabel;
            if (displayTitle.isEmpty()) {
                QString mv = (diskVendor + " " + diskModel).trimmed();
                displayTitle = mv.isEmpty() ? name : mv;
            }

            QVariantMap item;
            item["dev"] = devPath;
            item["name"] = displayTitle;
            item["shortDev"] = name;
            item["size"] = formatDriveSize(szBytes);
            item["fstype"] = fstype.isEmpty() ? "USB" : fstype.toUpper();
            item["mountpoint"] = mp;
            item["mounted"] = !mp.isEmpty();
            result.append(item);
        };

        for (const QJsonValue &dv : blockdevs) {
            QJsonObject d = dv.toObject();
            QString dName = d["name"].toString();
            if (dName.startsWith("zram") || dName.startsWith("loop") || dName.startsWith("sr")) continue;

            QString tran = d["tran"].toString().trimmed().toLower();
            bool diskRm = jsonToBool(d["rm"]) || jsonToBool(d["hotplug"]) || (tran == "usb") || (tran == "mmc");
            QString model = d["model"].toString().trimmed();
            QString vendor = d["vendor"].toString().trimmed();

            QJsonArray children = d["children"].toArray();
            // Проверяем, нет ли на диске системных разделов (/, /boot, /home)
            bool hasSysMount = false;
            qint64 maxPartBytes = 0;
            for (const QJsonValue &cv : children) {
                QJsonObject cObj = cv.toObject();
                qint64 cb = jsonToBytes(cObj["size"]);
                if (cb > maxPartBytes) maxPartBytes = cb;
                QString cmp = cObj["mountpoint"].toString().trimmed();
                if (isSystemMountPoint(cmp)) hasSysMount = true;
                if (cObj.contains("mountpoints")) {
                    for (const QJsonValue &mv : cObj["mountpoints"].toArray()) {
                        if (isSystemMountPoint(mv.toString().trimmed())) hasSysMount = true;
                    }
                }
            }
            if (hasSysMount) continue;

            if (children.isEmpty()) {
                parsePartObj(d, model, vendor, diskRm, jsonToBytes(d["size"]), 1);
            } else {
                int sibCnt = children.size();
                for (const QJsonValue &cv : children) {
                    parsePartObj(cv.toObject(), model, vendor, diskRm, maxPartBytes, sibCnt);
                }
            }
        }

        if (m_usbDrives != result) {
            m_usbDrives = result;
            emit usbDrivesChanged();
        }
    });
    p->start("lsblk", {"-J", "-b", "-o", "NAME,PATH,LABEL,PARTLABEL,MODEL,VENDOR,SIZE,FSTYPE,MOUNTPOINT,MOUNTPOINTS,RM,TRAN,TYPE,HOTPLUG"});
}

void DevicesManager::mountUsbDrive(const QString &devPath) {
    if (devPath.trimmed().isEmpty()) return;
    m_usbStatusText = "Монтирование " + devPath + "...";
    emit usbDrivesChanged();
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, devPath]() {
        QString err = QString::fromUtf8(p->readAllStandardError()).trimmed();
        QString out = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
        p->deleteLater();
        m_usbStatusText = err.isEmpty() ? (out.isEmpty() ? ("Смонтировано: " + devPath) : out) : err;
        refreshUsbDrives();
    });
    p->start("udisksctl", {"mount", "-b", devPath.trimmed(), "--no-user-interaction"});
}

static QString baseDiskPrefix(const QString &devPath) {
    QString clean = devPath.trimmed();
    QRegularExpression re("^(/dev/(?:sd[a-z]+|nvme\d+n\d+|mmcblk\d+))");
    auto m = re.match(clean);
    return m.hasMatch() ? m.captured(1) : clean;
}

void DevicesManager::unmountUsbDrive(const QString &devPath) {
    if (devPath.trimmed().isEmpty()) return;
    QString baseDisk = baseDiskPrefix(devPath);
    m_usbStatusText = "Сброс кэша и отмонтирование " + devPath + "...";
    emit usbDrivesChanged();
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, devPath]() {
        QString err = QString::fromUtf8(p->readAllStandardError()).trimmed();
        QString out = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
        p->deleteLater();
        m_usbStatusText = err.isEmpty() ? (out.isEmpty() ? ("Отмонтировано: " + devPath + " (можно извлекать)") : out) : err;
        refreshUsbDrives();
    });
    QString cmd = QString("sync && udisksctl unmount -b '%1' --no-user-interaction; "
                          "for p in %2?* ; do [ "$p" != '%1' ] && udisksctl unmount -b "$p" --no-user-interaction >/dev/null 2>&1 || true; done")
                  .arg(devPath.trimmed(), baseDisk);
    p->start("/bin/sh", {"-c", cmd});
}

void DevicesManager::ejectUsbDrive(const QString &devPath) {
    if (devPath.trimmed().isEmpty()) return;
    QString baseDisk = baseDiskPrefix(devPath);
    m_usbStatusText = "Безопасное извлечение " + devPath + "...";
    emit usbDrivesChanged();
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, devPath]() {
        QString err = QString::fromUtf8(p->readAllStandardError()).trimmed();
        p->deleteLater();
        m_usbStatusText = err.isEmpty() ? ("Накопитель " + devPath + " безопасно отключен") : err;
        refreshUsbDrives();
    });
    QString cmd = QString("sync; for p in %2?* ; do udisksctl unmount -b "$p" --no-user-interaction >/dev/null 2>&1 || true; done; "
                          "udisksctl unmount -b '%1' --no-user-interaction >/dev/null 2>&1 || true; "
                          "udisksctl power-off -b '%1' --no-user-interaction").arg(devPath.trimmed(), baseDisk);
    p->start("/bin/sh", {"-c", cmd});
}

void DevicesManager::openUsbDriveFolder(const QString &mountPoint) {
    if (mountPoint.trimmed().isEmpty()) return;
    QProcess::startDetached("xdg-open", {mountPoint.trimmed()});
}

void DevicesManager::checkTouchpad() {
    QProcess p;
    p.start("hyprctl", {"devices"});
    p.waitForFinished();
    QString out = QString::fromUtf8(p.readAllStandardOutput()).toLower();
    m_hasTouchpad = out.contains("touchpad") || out.contains("trackpoint");
}

void DevicesManager::loadSettings() {
    QString p = QDir::homePath() + "/.config/hypr/scripts/devices.conf";
    QFile f(p);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            int eq = line.indexOf('=');
            if (eq == -1) continue;
            QString k = line.left(eq).trimmed();
            QString v = line.mid(eq + 1).trimmed();

            if (k == "kb_layout") m_kbLayout = v;
            else if (k == "kb_options") m_kbOptions = v;
            else if (k == "numlock") m_numlock = (v == "1" || v == "true");
            else if (k == "repeat_rate") m_repeatRate = v.toInt();
            else if (k == "repeat_delay") m_repeatDelay = v.toInt();
            else if (k == "mouse_sensitivity") m_mouseSensitivity = v.toDouble();
            else if (k == "accel_profile") m_accelProfile = v;
            else if (k == "follow_mouse") m_followMouse = v.toInt();
            else if (k == "natural_scroll") m_naturalScroll = (v == "1" || v == "true");
            else if (k == "scroll_factor") m_scrollFactor = v.toDouble();
            else if (k == "left_handed") m_leftHanded = (v == "1" || v == "true");
            else if (k == "mouse_refocus") m_mouseRefocus = (v == "1" || v == "true");
            else if (k == "float_switch_override") m_floatSwitchOverride = v.toInt();
        }
    }
}

void DevicesManager::saveAndApply() {
    QProcess::startDetached("hyprctl", {"keyword", "input:numlock_by_default", m_numlock ? "true" : "false"});
    QProcess::startDetached("hyprctl", {"keyword", "input:repeat_rate", QString::number(m_repeatRate)});
    QProcess::startDetached("hyprctl", {"keyword", "input:repeat_delay", QString::number(m_repeatDelay)});
    QProcess::startDetached("hyprctl", {"keyword", "input:kb_layout", m_kbLayout});
    QProcess::startDetached("hyprctl", {"keyword", "input:kb_options", m_kbOptions});

    QProcess::startDetached("hyprctl", {"keyword", "input:sensitivity", QString::number(m_mouseSensitivity, 'f', 2)});
    QProcess::startDetached("hyprctl", {"keyword", "input:accel_profile", m_accelProfile});
    QProcess::startDetached("hyprctl", {"keyword", "input:follow_mouse", QString::number(m_followMouse)});
    QProcess::startDetached("hyprctl", {"keyword", "input:natural_scroll", m_naturalScroll ? "true" : "false"});
    QProcess::startDetached("hyprctl", {"keyword", "input:scroll_factor", QString::number(m_scrollFactor, 'f', 2)});
    QProcess::startDetached("hyprctl", {"keyword", "input:left_handed", m_leftHanded ? "true" : "false"});
    QProcess::startDetached("hyprctl", {"keyword", "input:mouse_refocus", m_mouseRefocus ? "true" : "false"});
    QProcess::startDetached("hyprctl", {"keyword", "input:float_switch_override_focus", QString::number(m_floatSwitchOverride)});

    QString confPath = QDir::homePath() + "/.config/hypr/scripts/devices.conf";
    QFile f(confPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&f);
        out << "kb_layout=" << m_kbLayout << "\n"
            << "kb_options=" << m_kbOptions << "\n"
            << "numlock=" << (m_numlock ? 1 : 0) << "\n"
            << "repeat_rate=" << m_repeatRate << "\n"
            << "repeat_delay=" << m_repeatDelay << "\n"
            << "mouse_sensitivity=" << QString::number(m_mouseSensitivity, 'f', 2) << "\n"
            << "accel_profile=" << m_accelProfile << "\n"
            << "follow_mouse=" << m_followMouse << "\n"
            << "natural_scroll=" << (m_naturalScroll ? 1 : 0) << "\n"
            << "scroll_factor=" << QString::number(m_scrollFactor, 'f', 2) << "\n"
            << "left_handed=" << (m_leftHanded ? 1 : 0) << "\n"
            << "mouse_refocus=" << (m_mouseRefocus ? 1 : 0) << "\n"
            << "float_switch_override=" << m_floatSwitchOverride << "\n";
    }

    QString luaPath = QDir::homePath() + "/.config/hypr/devices.lua";
    QFile lf(luaPath);
    if (lf.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&lf);
        out << "-- Auto-generated by Control Center\n"
            << "hl.config({\n"
            << "    input = {\n"
            << "        kb_layout = \"" << m_kbLayout << "\",\n"
            << "        kb_options = \"" << m_kbOptions << "\",\n"
            << "        numlock_by_default = " << (m_numlock ? "true" : "false") << ",\n"
            << "        repeat_rate = " << m_repeatRate << ",\n"
            << "        repeat_delay = " << m_repeatDelay << ",\n"
            << "        sensitivity = " << QString::number(m_mouseSensitivity, 'f', 2) << ",\n"
            << "        accel_profile = \"" << m_accelProfile << "\",\n"
            << "        follow_mouse = " << m_followMouse << ",\n"
            << "        natural_scroll = " << (m_naturalScroll ? "true" : "false") << ",\n"
            << "        scroll_factor = " << QString::number(m_scrollFactor, 'f', 2) << ",\n"
            << "        left_handed = " << (m_leftHanded ? "true" : "false") << ",\n"
            << "        mouse_refocus = " << (m_mouseRefocus ? "true" : "false") << ",\n"
            << "        float_switch_override_focus = " << m_floatSwitchOverride << ",\n"
            << "    },\n"
            << "})\n";
    }
}

void DevicesManager::setKbLayout(const QString &v) { if (m_kbLayout != v) { m_kbLayout = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setKbOptions(const QString &v) { if (m_kbOptions != v) { m_kbOptions = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setNumlock(bool v) { if (m_numlock != v) { m_numlock = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setRepeatRate(int v) { v = std::clamp(v, 10, 80); if (m_repeatRate != v) { m_repeatRate = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setRepeatDelay(int v) { v = std::clamp(v, 200, 1200); if (m_repeatDelay != v) { m_repeatDelay = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setMouseSensitivity(qreal v) { v = std::clamp(v, -1.0, 1.0); if (!qFuzzyCompare(m_mouseSensitivity, v)) { m_mouseSensitivity = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setAccelProfile(const QString &v) { if (m_accelProfile != v) { m_accelProfile = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setFollowMouse(int v) { if (m_followMouse != v) { m_followMouse = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setNaturalScroll(bool v) { if (m_naturalScroll != v) { m_naturalScroll = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setScrollFactor(qreal v) { v = std::clamp(v, 0.2, 4.0); if (!qFuzzyCompare(m_scrollFactor, v)) { m_scrollFactor = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setLeftHanded(bool v) { if (m_leftHanded != v) { m_leftHanded = v; emit deviceChanged(); saveAndApply(); } }
void DevicesManager::setMouseRefocus(bool v) { if (m_mouseRefocus != v) { m_mouseRefocus = v; emit deviceChanged(); saveAndApply(); } }

void DevicesManager::stepRepeatRate(int delta) { setRepeatRate(m_repeatRate + delta); }
void DevicesManager::stepRepeatDelay(int delta) { setRepeatDelay(m_repeatDelay + delta); }
void DevicesManager::stepSensitivity(qreal delta) { setMouseSensitivity(m_mouseSensitivity + delta); }
void DevicesManager::stepScrollFactor(qreal delta) { setScrollFactor(m_scrollFactor + delta); }
