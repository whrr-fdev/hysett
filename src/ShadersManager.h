#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>

class ShadersManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList shaders READ shaders NOTIFY shadersChanged)
    Q_PROPERTY(QString currentShader READ currentShader NOTIFY currentShaderChanged)

public:
    explicit ShadersManager(QObject *parent = nullptr);

    QVariantList shaders() const { return m_shaders; }
    QString currentShader() const { return m_currentShader; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void applyShader(const QString &name);
    Q_INVOKABLE void clearShader();

signals:
    void shadersChanged();
    void currentShaderChanged();

private:
    void scanShaders();
    void checkCurrentShader();

    QVariantList m_shaders;
    QString m_currentShader;
};
