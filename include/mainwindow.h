#ifndef MAINWINDOW_H
#define MAINWINDOW_H
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QTranslator>
#include "steamintegration.h"
#include "minesweeperlogic.h"
#include "gametimer.h"

class MainWindow : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool showWelcome READ getShowWelcome CONSTANT)
    Q_PROPERTY(bool unlockedFlag1 READ getUnlockedFlag1 CONSTANT)
    Q_PROPERTY(bool unlockedFlag2 READ getUnlockedFlag2 CONSTANT)
    Q_PROPERTY(bool unlockedFlag3 READ getUnlockedFlag3 CONSTANT)
    Q_PROPERTY(bool unlockedAnim1 READ getUnlockedAnim1 CONSTANT)
    Q_PROPERTY(bool unlockedAnim2 READ getUnlockedAnim2 CONSTANT)
    Q_PROPERTY(QString playerName READ getPlayerName CONSTANT)
    Q_PROPERTY(bool gamescope READ isGamescope CONSTANT)
    Q_PROPERTY(int languageIndex READ getLanguageIndex NOTIFY languageIndexChanged)
    Q_PROPERTY(bool steamEnabled READ getSteamEnabled CONSTANT)
    Q_PROPERTY(bool isFluent READ getIsFluent NOTIFY fluentChanged)
    Q_PROPERTY(bool isUniversal READ getIsUniversal NOTIFY universalChanged)
    Q_PROPERTY(bool isFusion READ getIsFusion NOTIFY fusionChanged)

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow() override;

    // Initial setup methods
    void init();
    void setQMLStyle(int index);
    Q_INVOKABLE void setThemeColorScheme(int ColorSchemeIndex);
    Q_INVOKABLE void setLanguage(int index);

    // Getter methods for engine setup
    SteamIntegration* getSteamIntegration() const { return m_steamIntegration; }
    MinesweeperLogic* getGameLogic() const { return m_gameLogic; }
    GameTimer* getGameTimer() const { return m_gameTimer; }
    bool shouldResetSettings() const { return !settings.value("welcomeMessageShown", false).toBool(); }

    // QML invokable methods
    Q_INVOKABLE void deleteSaveFile(const QString &filename);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename) const;
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void restartRetr0Mine(int index = 0);
    Q_INVOKABLE bool saveLeaderboard(const QString &data) const;
    Q_INVOKABLE QString loadLeaderboard() const;
    Q_INVOKABLE void resetSettings();

    // Property getters
    bool getSteamEnabled() const { return m_steamEnabled; }
    bool getShowWelcome() const { return shouldShowWelcomeMessage; }
    bool getUnlockedFlag1() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_EASY"); }
    bool getUnlockedFlag2() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_MEDIUM"); }
    bool getUnlockedFlag3() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_HARD"); }
    bool getUnlockedAnim1() const { return m_steamIntegration->isAchievementUnlocked("ACH_HINT_MASTER"); }
    bool getUnlockedAnim2() const { return m_steamIntegration->isAchievementUnlocked("ACH_SPEED_DEMON"); }
    QString getPlayerName() const { return m_steamIntegration->getSteamUserName(); }
    bool isGamescope() const { return isRunningOnGamescope; }
    int getLanguageIndex() const { return m_languageIndex; }
    bool getIsFluent() const { return m_isFluent; }
    bool getIsUniversal() const { return m_isUniversal; }
    bool getIsFusion() const { return m_isFusion; }

    QSettings settings;
    SteamIntegration *m_steamIntegration;
    MinesweeperLogic *m_gameLogic;
    GameTimer *m_gameTimer;
private:
    QTranslator *translator;

    int currentTheme;
    bool isRunningOnGamescope;
    bool shouldShowWelcomeMessage;
    bool loadLanguage(QString languageCode);
    QString getLeaderboardPath() const;
    int m_languageIndex;
    bool m_steamEnabled;
    bool m_isFluent = true;
    bool m_isUniversal = false;
    bool m_isFusion = false;

signals:
    void languageIndexChanged();
    void fluentChanged();
    void universalChanged();
    void fusionChanged();
};

struct MainWindowForeign
{
    Q_GADGET
    QML_FOREIGN(MainWindow)
    QML_SINGLETON
    QML_NAMED_ELEMENT(MainWindow)
public:
    inline static MainWindow* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;  // Moved to public

    static MainWindow* create(QQmlEngine*, QJSEngine* engine)
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

#endif // MAINWINDOW_H
