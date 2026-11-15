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
#include <QFile>
#include <malloc.h>
#include <sys/mman.h>

static void dropColdFileBackedPages() {
    QFile maps("/proc/self/maps");
    if (!maps.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    const QByteArray raw = maps.readAll();
    maps.close();
    for (const QByteArray &line : raw.split('\n')) {
        if (line.isEmpty() || !line.contains('/')) continue;
        if (line.contains(" r--p ") || line.contains(" r-xp ")) {
            int dash = line.indexOf('-');
            int sp = line.indexOf(' ');
            if (dash > 0 && sp > dash) {
                bool ok1 = false, ok2 = false;
                uintptr_t start = line.left(dash).toULongLong(&ok1, 16);
                uintptr_t end = line.mid(dash + 1, sp - dash - 1).toULongLong(&ok2, 16);
                if (ok1 && ok2 && end > start) {
                    madvise(reinterpret_cast<void *>(start), end - start, MADV_DONTNEED);
                }
            }
        }
    }
}

static void performMemoryTrim(QQmlApplicationEngine *mainEngine, bool deepClean) {
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QPixmapCache::clear();

    if (mainEngine) {
        mainEngine->collectGarbage();
        if (deepClean) {
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
            if (deepClean) {
                qw->releaseResources();
            }
        }
    }

    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    malloc_trim(0);
    if (deepClean) {
        dropColdFileBackedPages();
    }
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
    QTimer::singleShot(160, [eng]() { performMemoryTrim(eng, false); });
}

void HyprIpc::deepCleanMemory() {
    QQmlApplicationEngine *eng = m_engine;
    QTimer::singleShot(200, [eng]() { performMemoryTrim(eng, true); });
}
