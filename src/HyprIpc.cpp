#include <QGuiApplication>
#include <QCoreApplication>
#include <QWindow>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQmlEngine>
#include <QQmlContext>
#include <QPixmapCache>
#include <QTimer>
#include <malloc.h>

static void performDeepMemoryTrim() {
    for (QWindow *w : QGuiApplication::topLevelWindows()) {
        if (w->isVisible()) {
            // Пока окно открыто — ничего не выгружаем, чтобы все анимации шли в 160 FPS без лагов!
            return;
        }
    }

    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QPixmapCache::clear();

    for (QWindow *w : QGuiApplication::topLevelWindows()) {
        if (auto *qw = qobject_cast<QQuickWindow *>(w)) {
            QQmlEngine *eng = qmlEngine(qw);
            if (!eng && qw->contentItem()) eng = qmlEngine(qw->contentItem());
            if (eng) {
                eng->collectGarbage();
                eng->trimComponentCache();
            }
            qw->releaseResources();
        }
    }

    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    malloc_trim(0);
}

#include <QGuiApplication>
#include <QWindow>
#include "HyprIpc.h"
#include <QProcess>
#include <QPixmapCache>
#include <malloc.h>

HyprIpc::HyprIpc(QObject *parent) : QObject(parent) {}

void HyprIpc::dispatch(const QString &cmd) {
    QProcess::startDetached("hyprctl", QStringList() << "dispatch" << cmd.split(' '));
}

QString HyprIpc::getActiveWorkspace() {
    QProcess process;
    process.start("hyprctl", QStringList() << "activeworkspace" << "-j");
    process.waitForFinished();
    return QString::fromUtf8(process.readAllStandardOutput());
}

void HyprIpc::trimMemory() {
    QTimer::singleShot(250, []() { performDeepMemoryTrim(); });
}
