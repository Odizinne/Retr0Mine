#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QColor>
#include <QTranslator>
#include <QTimer>
#include "SteamIntegration.h"
#include "MinesweeperLogic.h"
#include "GameTimer.h"

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
    Q_PROPERTY(bool isDarkMode READ getDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(int languageIndex READ getLanguageIndex NOTIFY languageIndexChanged)
    Q_PROPERTY(bool steamEnabled READ getSteamEnabled CONSTANT)

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow() override;

    Q_INVOKABLE void setLanguage(int index);
    Q_INVOKABLE void deleteSaveFile(const QString &filename);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename) const;
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void restartRetr0Mine(int index);
    Q_INVOKABLE bool saveLeaderboard(const QString &data) const;
    Q_INVOKABLE QString loadLeaderboard() const;
    Q_INVOKABLE void resetSettings();
    Q_INVOKABLE void setThemeColorScheme(int ColorSchemeIndex);

    bool getSteamEnabled() const { return m_steamEnabled; }
    bool getShowWelcome() const { return shouldShowWelcomeMessage; }
    bool getUnlockedFlag1() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_EASY"); }
    bool getUnlockedFlag2() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_MEDIUM"); }
    bool getUnlockedFlag3() const { return m_steamIntegration->isAchievementUnlocked("ACH_NO_HINT_HARD"); }
    bool getUnlockedAnim1() const { return m_steamIntegration->isAchievementUnlocked("ACH_HINT_MASTER"); }
    bool getUnlockedAnim2() const { return m_steamIntegration->isAchievementUnlocked("ACH_SPEED_DEMON"); }
    QString getPlayerName() const { return m_steamIntegration->getSteamUserName(); }
    bool isGamescope() const { return isRunningOnGamescope; }
    bool getDarkMode() const { return m_isDarkMode; }
    int getLanguageIndex() const { return m_languageIndex; }

private slots:
    void onColorSchemeChanged();

private:
    QQmlApplicationEngine *engine;
    QSettings settings;
    QQmlContext *rootContext;
    QTranslator *translator;
    SteamIntegration *m_steamIntegration;
    MinesweeperLogic *m_gameLogic;
    GameTimer *m_gameTimer;
    int currentTheme;
    bool isRunningOnGamescope;
    bool shouldShowWelcomeMessage;

    void setupAndLoadQML();
    void setQMLStyle(int index);
    void setColorScheme();
    bool loadLanguage(QString languageCode);
    QString getLeaderboardPath() const;

    bool m_isDarkMode;
    int m_languageIndex;
    bool m_steamEnabled;

signals:
    void darkModeChanged();
    void languageIndexChanged();

};

#endif // MAINWINDOW_H
