#include "HyprIpc.h"
#include <QGuiApplication>
#include <QCoreApplication>
#include <QWindow>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQmlEngine>
#include <QQmlContext>
#include <QPixmapCache>
#include <QProcess>
#include <QTimer>
#include <malloc.h>

static void performDeepMemoryTrim(QQmlApplicationEngine *mainEngine) {
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QPixmapCache::clear();

    if (mainEngine) {
        mainEngine->collectGarbage();
        mainEngine->trimComponentCache();
    }

    for (QWindow *w : QGuiApplication::topLevelWindows()) {
        if (auto *qw = qobject_cast<QQuickWindow *>(w)) {
            QQmlEngine *eng = qmlEngine(qw);
            if (!eng && qw->contentItem()) eng = qmlEngine(qw->contentItem());
            if (eng && eng != mainEngine) {
                eng->collectGarbage();
                eng->trimComponentCache();
            }
        }
    }

    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    malloc_trim(0);
}

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
    QQmlApplicationEngine *eng = m_engine;
    QTimer::singleShot(180, [eng]() { performDeepMemoryTrim(eng); });
}
