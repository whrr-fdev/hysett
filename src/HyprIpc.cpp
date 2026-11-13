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

static void performMemoryTrim(QQmlApplicationEngine *mainEngine, bool trimComponents) {
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QPixmapCache::clear();

    if (mainEngine) {
        mainEngine->collectGarbage();
        if (trimComponents) {
            mainEngine->trimComponentCache();
        }
    }

    for (QWindow *w : QGuiApplication::topLevelWindows()) {
        if (auto *qw = qobject_cast<QQuickWindow *>(w)) {
            QQmlEngine *eng = qmlEngine(qw);
            if (!eng && qw->contentItem()) eng = qmlEngine(qw->contentItem());
            if (eng && eng != mainEngine) {
                eng->collectGarbage();
            }
        }
    }

    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    malloc_trim(0);
}

HyprIpc::HyprIpc(QObject *parent) : QObject(parent) {}

void HyprIpc::dispatch(const QString &cmd) {
    QProcess::startDetached("sh", {"-c", "hyprctl dispatch " + cmd + " >/dev/null 2>&1"});
}

QString HyprIpc::getActiveWorkspace() {
    QProcess process;
    process.start("hyprctl", QStringList() << "activeworkspace" << "-j");
    process.waitForFinished();
    return QString::fromUtf8(process.readAllStandardOutput());
}

void HyprIpc::trimMemory() {
    QQmlApplicationEngine *eng = m_engine;
    QTimer::singleShot(180, [eng]() { performMemoryTrim(eng, false); });
}

void HyprIpc::deepCleanMemory() {
    QQmlApplicationEngine *eng = m_engine;
    QTimer::singleShot(220, [eng]() { performMemoryTrim(eng, true); });
}
