#ifndef STEAMINTEGRATION_H
#define STEAMINTEGRATION_H

#include <QObject>
#include <steam_api.h>

class SteamIntegration : public QObject
{
    Q_OBJECT
public:
    explicit SteamIntegration(QObject *parent = nullptr);
    ~SteamIntegration();
    bool initialize();
    void shutdown();
    Q_INVOKABLE void unlockAchievement(const QString &achievementId);
    Q_INVOKABLE bool isAchievementUnlocked(const QString &achievementId);
    Q_INVOKABLE bool isRunningOnDeck();
    bool m_initialized;
};

#endif // STEAMINTEGRATION_H
