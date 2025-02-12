#include "SteamIntegration.h"
#include <QDebug>

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
{}

SteamIntegration::~SteamIntegration()
{
    shutdown();
}

bool SteamIntegration::initialize()
{
    if (m_initialized)
        return true;
    if (!SteamAPI_Init()) {
        qWarning() << "Failed to initialize Steam API";
        return false;
    }
    m_initialized = true;
    return true;
}

void SteamIntegration::shutdown()
{
    if (m_initialized) {
        SteamAPI_Shutdown();
        m_initialized = false;
    }
}

void SteamIntegration::unlockAchievement(const QString &achievementId)
{
    if (!m_initialized)
        return;
    ISteamUserStats *steamUserStats = SteamUserStats();
    if (!steamUserStats)
        return;
    steamUserStats->SetAchievement(achievementId.toUtf8().constData());
    steamUserStats->StoreStats();
}

bool SteamIntegration::isAchievementUnlocked(const QString &achievementId)
{
    if (!m_initialized)
        return false;
    ISteamUserStats *steamUserStats = SteamUserStats();
    if (!steamUserStats)
        return false;
    bool achieved = false;
    steamUserStats->GetAchievement(achievementId.toUtf8().constData(), &achieved);
    return achieved;
}

bool SteamIntegration::isRunningOnDeck()
{
    if (!m_initialized)
        return false;
    ISteamUtils *steamUtils = SteamUtils();
    if (!steamUtils)
        return false;
    return steamUtils->IsSteamRunningOnSteamDeck();
}

QString SteamIntegration::getSteamUILanguage() const
{
    if (!m_initialized)
        return QString();

    ISteamUtils* steamUtils = SteamUtils();
    if (!steamUtils)
        return QString();

    const char* language = steamUtils->GetSteamUILanguage();
    return QString::fromUtf8(language);
}

QString SteamIntegration::getSteamUserName() const
{
    if (!m_initialized)
        return QString();

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return QString();

    return QString::fromUtf8(steamFriends->GetPersonaName());
}

bool SteamIntegration::incrementTotalWin()
{
    if (!m_initialized)
        return false;

    ISteamUserStats *steamUserStats = SteamUserStats();
    if (!steamUserStats)
        return false;

    int currentWins = 0;
    if (!steamUserStats->GetStat("TOTAL_WIN", &currentWins))
        return false;

    if (!steamUserStats->SetStat("TOTAL_WIN", currentWins + 1))
        return false;

    return steamUserStats->StoreStats();
}
