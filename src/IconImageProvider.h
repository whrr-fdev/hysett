#pragma once
#include <QQuickImageProvider>
#include <QIcon>
#include <QImage>

class IconImageProvider : public QQuickImageProvider {
public:
    IconImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
