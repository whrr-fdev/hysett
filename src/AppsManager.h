#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QProcess>

class AppsManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)
    Q_PROPERTY(QVariantList hiddenApps READ hiddenApps NOTIFY appsChanged)
    Q_PROPERTY(int hiddenCount READ hiddenCount NOTIFY appsChanged)
    Q_PROPERTY(QVariantList fileResults READ fileResults NOTIFY fileResultsChanged)
    Q_PROPERTY(bool isSearching READ isSearching NOTIFY isSearchingChanged)
    Q_PROPERTY(QVariantList packageResults READ packageResults NOTIFY packageResultsChanged)
    Q_PROPERTY(bool isSearchingPackages READ isSearchingPackages NOTIFY isSearchingPackagesChanged)
    Q_PROPERTY(bool isPkgActionRunning READ isPkgActionRunning NOTIFY pkgActionStateChanged)
    Q_PROPERTY(QString pkgActionStatus READ pkgActionStatus NOTIFY pkgActionStateChanged)
    Q_PROPERTY(bool pkgActionSuccess READ pkgActionSuccess NOTIFY pkgActionStateChanged)
    Q_PROPERTY(bool pkgActionFinished READ pkgActionFinished NOTIFY pkgActionStateChanged)

public:
    explicit AppsManager(QObject *parent = nullptr);

    QVariantList apps() const { return m_apps; }
    QVariantList hiddenApps() const { return m_hiddenApps; }
    int hiddenCount() const { return m_hiddenApps.size(); }
    QVariantList fileResults() const { return m_fileResults; }
    bool isSearching() const { return m_isSearching; }
    QVariantList packageResults() const { return m_packageResults; }
    bool isSearchingPackages() const { return m_isSearchingPackages; }
    bool isPkgActionRunning() const { return m_isPkgActionRunning; }
    QString pkgActionStatus() const { return m_pkgActionStatus; }
    bool pkgActionSuccess() const { return m_pkgActionSuccess; }
    bool pkgActionFinished() const { return m_pkgActionFinished; }

    Q_INVOKABLE void launchApp(const QString &exec);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void searchFiles(const QString &query, bool wholeSystem = false);
    Q_INVOKABLE void clearFileSearch();
    Q_INVOKABLE void openFile(const QString &path);
    Q_INVOKABLE void openContainingFolder(const QString &path);
    Q_INVOKABLE void copyPath(const QString &path);

    // Управление ярлыками и пакетами (ПКМ, скрытые, Pacman/AUR)
    Q_INVOKABLE QVariantMap getAppUninstallInfo(const QString &desktopPath, const QString &exec);
    Q_INVOKABLE bool removeOrHideShortcut(const QString &desktopPath);
    Q_INVOKABLE bool unhideShortcut(const QString &desktopPath);
    Q_INVOKABLE void restoreHiddenShortcuts();
    Q_INVOKABLE void searchPackages(const QString &query);
    Q_INVOKABLE void clearPackageSearch();
    Q_INVOKABLE void executePackageAction(const QString &action, const QString &packageName,
                                          const QString &repo, const QString &flatpakId,
                                          const QString &desktopPath, const QString &password);
    Q_INVOKABLE void resetPkgActionState();

signals:
    void appsChanged();
    void fileResultsChanged();
    void isSearchingChanged();
    void packageResultsChanged();
    void isSearchingPackagesChanged();
    void pkgActionStateChanged();

private:
    void scanDesktopFiles();
    QVariantList m_apps;
    QVariantList m_hiddenApps;
    QVariantList m_fileResults;
    QVariantList m_packageResults;
    bool m_isSearching = false;
    bool m_isSearchingPackages = false;
    bool m_isPkgActionRunning = false;
    bool m_pkgActionSuccess = false;
    bool m_pkgActionFinished = false;
    QString m_pkgActionStatus;
    QProcess *m_searchProc = nullptr;
    QProcess *m_pkgSearchProc = nullptr;
    QProcess *m_pkgActionProc = nullptr;
    QString m_currentSearchQuery;
};
