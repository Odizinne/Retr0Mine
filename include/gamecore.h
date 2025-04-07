#pragma once
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QTranslator>
#include <QPalette>
#include <QGuiApplication>
#include <QCursor>

class GameCore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool gamescope READ isGamescope CONSTANT)
    Q_PROPERTY(int languageIndex READ getLanguageIndex NOTIFY languageIndexChanged)
    Q_PROPERTY(QString qtVersion READ getQtVersion CONSTANT)
    Q_PROPERTY(bool darkMode READ getDarkMode CONSTANT)
    Q_PROPERTY(QString platformPlugin READ getPlatformPlugin CONSTANT)
public:
    explicit GameCore(QObject *parent = nullptr);
    ~GameCore() override;
    QString getPlatformPlugin() const {
        return qgetenv("QT_QPA_PLATFORM").isEmpty() ?
                   QGuiApplication::platformName() :
                   QString::fromUtf8(qgetenv("QT_QPA_PLATFORM"));
    }
    void init();
    QString getRenderingBackend();
    Q_INVOKABLE bool setTitlebarColor(int colorMode);
    Q_INVOKABLE void setThemeColorScheme(int ColorSchemeIndex);
    Q_INVOKABLE void setLanguage(int index);
    Q_INVOKABLE void deleteSaveFile(const QString &filename);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename);
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void restartRetr0Mine();
    Q_INVOKABLE void resetRetr0Mine();
    Q_INVOKABLE bool saveLeaderboard(const QString &data) const;
    Q_INVOKABLE QString loadLeaderboard() const;
    Q_INVOKABLE void setApplicationPalette(int systemAccent);
    Q_INVOKABLE void setCursor(bool customCursor);
    bool isGamescope() const { return isRunningOnGamescope; }
    int getLanguageIndex() const { return m_languageIndex; }
    QString getQtVersion() const { return QT_VERSION_STR; }
    bool getDarkMode() const { return false; }
    QSettings settings;

    // Add event filter to handle cursor changes
    bool eventFilter(QObject *watched, QEvent *event) override;

    Q_INVOKABLE QString getLogFilePath() const;
    Q_INVOKABLE bool writeToLogFile(const QString &logMessage) const;
    Q_INVOKABLE QStringList getLogFiles() const;
    Q_INVOKABLE QString readLogFile(const QString &filename) const;
    Q_INVOKABLE void cleanupOldLogFiles(int maxFiles = 10);

    Q_INVOKABLE int getCurrentMonitorAvailableHeight(QWindow* window = nullptr) const;
    Q_INVOKABLE int getCurrentMonitorAvailableWidth(QWindow* window = nullptr) const;

private:
    QTranslator *translator;
    bool isRunningOnGamescope;
    bool loadLanguage(QString languageCode);
    QString getLeaderboardPath() const;
    int m_languageIndex;
    int selectedAccentColor;
    void setCustomPalette();
    void setSystemPalette();
    int m_titlebarColorMode = -1;

    // Custom cursor handling
    bool m_useCustomCursor = true;
    QCursor m_customCursor;
    void applyCustomCursorForWindow(QWindow* window);
    void resetCursorForWindow(QWindow* window);

    QString m_currentLogFile;

signals:
    void languageIndexChanged();
    void saveCompleted(bool success);
};

struct GameCoreForeign
{
    Q_GADGET
    QML_FOREIGN(GameCore)
    QML_SINGLETON
    QML_NAMED_ELEMENT(GameCore)
public:
    inline static GameCore* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;
    static GameCore* create(QQmlEngine*, QJSEngine* engine)
    {
        Q_ASSERT(s_singletonInstance);
        Q_ASSERT(engine->thread() == s_singletonInstance->thread());
        if (s_engine)
            Q_ASSERT(engine == s_engine);
        else
            s_engine = engine;
        QJSEngine::setObjectOwnership(s_singletonInstance, QJSEngine::CppOwnership);
        return s_singletonInstance;
    }
};
