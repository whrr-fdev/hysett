#pragma once
#include <QObject>
#include <QString>

class DevicesManager : public QObject {
    Q_OBJECT

    // Клавиатура
    Q_PROPERTY(QString kbLayout READ kbLayout WRITE setKbLayout NOTIFY deviceChanged)
    Q_PROPERTY(QString kbOptions READ kbOptions WRITE setKbOptions NOTIFY deviceChanged)
    Q_PROPERTY(bool numlock READ numlock WRITE setNumlock NOTIFY deviceChanged)
    Q_PROPERTY(int repeatRate READ repeatRate WRITE setRepeatRate NOTIFY deviceChanged)
    Q_PROPERTY(int repeatDelay READ repeatDelay WRITE setRepeatDelay NOTIFY deviceChanged)

    // Мышь
    Q_PROPERTY(qreal mouseSensitivity READ mouseSensitivity WRITE setMouseSensitivity NOTIFY deviceChanged)
    Q_PROPERTY(QString accelProfile READ accelProfile WRITE setAccelProfile NOTIFY deviceChanged)
    Q_PROPERTY(int followMouse READ followMouse WRITE setFollowMouse NOTIFY deviceChanged)
    Q_PROPERTY(bool naturalScroll READ naturalScroll WRITE setNaturalScroll NOTIFY deviceChanged)
    Q_PROPERTY(qreal scrollFactor READ scrollFactor WRITE setScrollFactor NOTIFY deviceChanged)
    Q_PROPERTY(bool leftHanded READ leftHanded WRITE setLeftHanded NOTIFY deviceChanged)
    Q_PROPERTY(bool mouseRefocus READ mouseRefocus WRITE setMouseRefocus NOTIFY deviceChanged)

    // Тачпад
    Q_PROPERTY(bool hasTouchpad READ hasTouchpad NOTIFY deviceChanged)

public:
    explicit DevicesManager(QObject *parent = nullptr);

    QString kbLayout() const { return m_kbLayout; }
    void setKbLayout(const QString &v);

    QString kbOptions() const { return m_kbOptions; }
    void setKbOptions(const QString &v);

    bool numlock() const { return m_numlock; }
    void setNumlock(bool v);

    int repeatRate() const { return m_repeatRate; }
    void setRepeatRate(int v);

    int repeatDelay() const { return m_repeatDelay; }
    void setRepeatDelay(int v);

    qreal mouseSensitivity() const { return m_mouseSensitivity; }
    void setMouseSensitivity(qreal v);

    QString accelProfile() const { return m_accelProfile; }
    void setAccelProfile(const QString &v);

    int followMouse() const { return m_followMouse; }
    void setFollowMouse(int v);

    bool naturalScroll() const { return m_naturalScroll; }
    void setNaturalScroll(bool v);

    qreal scrollFactor() const { return m_scrollFactor; }
    void setScrollFactor(qreal v);

    bool leftHanded() const { return m_leftHanded; }
    void setLeftHanded(bool v);

    bool mouseRefocus() const { return m_mouseRefocus; }
    void setMouseRefocus(bool v);

    bool hasTouchpad() const { return m_hasTouchpad; }

    Q_INVOKABLE void stepRepeatRate(int delta);
    Q_INVOKABLE void stepRepeatDelay(int delta);
    Q_INVOKABLE void stepSensitivity(qreal delta);
    Q_INVOKABLE void stepScrollFactor(qreal delta);

signals:
    void deviceChanged();

private:
    void loadSettings();
    void saveAndApply();
    void checkTouchpad();

    QString m_kbLayout = "us,ru";
    QString m_kbOptions = "grp:alt_shift_toggle";
    bool m_numlock = true;
    int m_repeatRate = 25;
    int m_repeatDelay = 600;

    qreal m_mouseSensitivity = 0.0;
    QString m_accelProfile = "default";
    int m_followMouse = 1;
    bool m_naturalScroll = false;
    qreal m_scrollFactor = 1.0;
    bool m_leftHanded = false;
    bool m_mouseRefocus = true;
    int m_floatSwitchOverride = 1;

    bool m_hasTouchpad = false;
};
