#pragma once

#include <QObject>
#include <QQmlEngine>
#include <steam_api.h>

class SteamIntegration : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool unlockedFlag1 READ getUnlockedFlag1 CONSTANT)
    Q_PROPERTY(bool unlockedFlag2 READ getUnlockedFlag2 CONSTANT)
    Q_PROPERTY(bool unlockedFlag3 READ getUnlockedFlag3 CONSTANT)
    Q_PROPERTY(bool unlockedAnim1 READ getUnlockedAnim1 CONSTANT)
    Q_PROPERTY(bool unlockedAnim2 READ getUnlockedAnim2 CONSTANT)
    Q_PROPERTY(QString playerName READ getPlayerName NOTIFY playerNameChanged)
    Q_PROPERTY(bool initialized READ isInitialized CONSTANT)

public:
    explicit SteamIntegration(QObject *parent = nullptr);

    bool initialize();
    void shutdown();
    Q_INVOKABLE void unlockAchievement(const QString &achievementId);
    Q_INVOKABLE bool isAchievementUnlocked(const QString &achievementId) const;
    Q_INVOKABLE bool isRunningOnDeck() const;
    Q_INVOKABLE bool incrementTotalWin();
    QString getSteamUILanguage() const;
    QString getPlayerName() const { return m_playerName; }
    bool isInitialized() const { return m_initialized; }

    // Getters for achievements
    bool getUnlockedFlag1() const { return isAchievementUnlocked("ACH_NO_HINT_EASY"); }
    bool getUnlockedFlag2() const { return isAchievementUnlocked("ACH_NO_HINT_MEDIUM"); }
    bool getUnlockedFlag3() const { return isAchievementUnlocked("ACH_NO_HINT_HARD"); }
    bool getUnlockedAnim1() const { return isAchievementUnlocked("ACH_HINT_MASTER"); }
    bool getUnlockedAnim2() const { return isAchievementUnlocked("ACH_SPEED_DEMON"); }

private:
    bool m_initialized;
    QString m_playerName;
    void updatePlayerName();

signals:
    void playerNameChanged();
};

struct SteamIntegrationForeign
{
    Q_GADGET
    QML_FOREIGN(SteamIntegration)
    QML_SINGLETON
    QML_NAMED_ELEMENT(SteamIntegration)
public:
    inline static SteamIntegration* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;

    static SteamIntegration* create(QQmlEngine*, QJSEngine* engine)
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
