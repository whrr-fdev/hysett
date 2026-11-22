#pragma once
#include <QObject>
#include <QQuickWindow>
#include <QString>

class WaybarManager;

class ScreenDrawController : public QObject {
    Q_OBJECT
public:
    explicit ScreenDrawController(WaybarManager *waybar, QObject *parent = nullptr);

    Q_INVOKABLE void setOverlayInput(QQuickWindow *win, bool captureInput, bool captureKeyboard);
    Q_INVOKABLE void hideOverlay(QQuickWindow *win);
    Q_INVOKABLE bool isRecordingNow() const;
    Q_INVOKABLE bool isScreenLocked() const;
    Q_INVOKABLE void requestTest();
    Q_INVOKABLE void requestClear();

public slots:
    void dispatchCommand(const QString &cmd);

signals:
    void drawDownRequested();
    void drawUpRequested();
    void drawToggleRequested();
    void drawClearRequested();
    void drawTestRequested();

private:
    WaybarManager *m_waybar = nullptr;
};
