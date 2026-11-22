#include "ScreenDrawController.h"
#include "WaybarManager.h"
#include <QGuiApplication>
#include <QScreen>
#include <QRegion>
#include <QFile>
#include <QProcess>
#include <QTimer>
#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Window>
#endif

ScreenDrawController::ScreenDrawController(WaybarManager *waybar, QObject *parent)
    : QObject(parent), m_waybar(waybar) {}

bool ScreenDrawController::isScreenLocked() const {
    return QFile::exists(QStringLiteral("/tmp/hysett_screen_locked"));
}

bool ScreenDrawController::isRecordingNow() const {
    if (isScreenLocked()) return false;
    if (m_waybar && m_waybar->recording()) return true;
    return QProcess::execute(QStringLiteral("pidof"), {QStringLiteral("-s"), QStringLiteral("gpu-screen-recorder")}) == 0;
}

void ScreenDrawController::setOverlayInput(QQuickWindow *win, bool captureInput, bool captureKeyboard) {
    if (!win) return;
    int w = win->width();
    int h = win->height();
    if (w <= 0 || h <= 0) {
        if (auto *scr = QGuiApplication::primaryScreen()) {
            w = scr->geometry().width();
            h = scr->geometry().height();
        }
        if (w <= 0) w = 1920;
        if (h <= 0) h = 1080;
    }

#ifdef HAVE_LAYERSHELLQT
    if (auto *ls = LayerShellQt::Window::get(win)) {
        ls->setLayer(LayerShellQt::Window::LayerOverlay);
        ls->setExclusiveZone(-1);
        ls->setAnchors(LayerShellQt::Window::Anchors(
            LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom |
            LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
        ls->setScope(QStringLiteral("hysett-draw"));
        ls->setKeyboardInteractivity(
            captureKeyboard
                ? LayerShellQt::Window::KeyboardInteractivityExclusive
                : LayerShellQt::Window::KeyboardInteractivityNone
        );
    }
#endif

    if (captureInput) {
        win->setWidth(w);
        win->setHeight(h);
        win->setMask(QRegion(0, 0, w, h));
        if (!win->isVisible()) {
            win->show();
            win->setMask(QRegion(0, 0, w, h));
        }
        if (captureKeyboard) {
            win->requestActivate();
            QTimer::singleShot(16, win, [win]() {
                if (win && win->isVisible()) win->requestActivate();
            });
        }
    } else {
        win->setMask(QRegion(-10, -10, 1, 1));
    }
    win->requestUpdate();
}

void ScreenDrawController::hideOverlay(QQuickWindow *win) {
    if (!win) return;
#ifdef HAVE_LAYERSHELLQT
    if (auto *ls = LayerShellQt::Window::get(win)) {
        ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    }
#endif
    win->setMask(QRegion(-10, -10, 1, 1));
    if (win->isVisible()) win->hide();
}

void ScreenDrawController::requestTest() {
    emit drawTestRequested();
}

void ScreenDrawController::requestClear() {
    emit drawClearRequested();
}

void ScreenDrawController::dispatchCommand(const QString &cmd) {
    if (cmd == QStringLiteral("down")) emit drawDownRequested();
    else if (cmd == QStringLiteral("up")) emit drawUpRequested();
    else if (cmd == QStringLiteral("toggle")) emit drawToggleRequested();
    else if (cmd == QStringLiteral("clear")) emit drawClearRequested();
}
