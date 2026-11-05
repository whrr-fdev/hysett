#include "ShadersManager.h"
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>

ShadersManager::ShadersManager(QObject *parent) : QObject(parent) {
    refresh();
}

void ShadersManager::refresh() {
    scanShaders();
    checkCurrentShader();
}

void ShadersManager::checkCurrentShader() {
    QProcess p;
    p.start("hyprctl", {"getoption", "decoration:screen_shader"});
    p.waitForFinished();
    QString out = QString::fromUtf8(p.readAllStandardOutput());

    QRegularExpression re("str:\\s*([^\\n]+)");
    auto m = re.match(out);
    if (m.hasMatch()) {
        QString full = m.captured(1).trimmed();
        if (full.isEmpty() || full == "[[EMPTY]]") {
            m_currentShader = "";
        } else {
            QFileInfo fi(full);
            m_currentShader = fi.baseName();
        }
    } else {
        m_currentShader = "";
    }
    emit currentShaderChanged();
}

void ShadersManager::scanShaders() {
    m_shaders.clear();
    QString shaderDir = QDir::homePath() + "/.config/hypr/shaders";
    QDir dir(shaderDir);
    if (!dir.exists()) return;

    QStringList files = dir.entryList({"*.frag"}, QDir::Files);
    for (const auto &f : files) {
        QFileInfo fi(f);
        QVariantMap s;
        s["name"] = fi.baseName();
        s["fileName"] = f;
        s["path"] = dir.filePath(f);
        m_shaders.append(s);
    }
    emit shadersChanged();
}

void ShadersManager::applyShader(const QString &name) {
    if (name.isEmpty()) {
        clearShader();
        return;
    }
    QString shaderPath = QDir::homePath() + "/.config/hypr/shaders/" + name + ".frag";
    QString cmd = QString("hl.config({ debug = { damage_tracking = 0 }, decoration = { screen_shader = '%1' } })").arg(shaderPath);
    QProcess::startDetached("hyprctl", {"eval", cmd});
    m_currentShader = name;
    emit currentShaderChanged();
}

void ShadersManager::clearShader() {
    QString cmd = "hl.config({ debug = { damage_tracking = 2 }, decoration = { screen_shader = '[[EMPTY]]' } })";
    QProcess::startDetached("hyprctl", {"eval", cmd});
    m_currentShader = "";
    emit currentShaderChanged();
}
