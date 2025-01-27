#include "SteamIntegration.h"
#include <QDebug>

SteamIntegration::SteamIntegration(QObject* parent)
    : QObject(parent)
    , m_initialized(false)
{
}

SteamIntegration::~SteamIntegration() {
    shutdown();
}

bool SteamIntegration::initialize() {
    if (m_initialized) return true;
    if (!SteamAPI_Init()) {
        qWarning() << "Failed to initialize Steam API";
        return false;
    }
    m_initialized = true;
    return true;
}

void SteamIntegration::shutdown() {
    if (m_initialized) {
        SteamAPI_Shutdown();
        m_initialized = false;
    }
}

void SteamIntegration::unlockAchievement(const QString& achievementId) {
    if (!m_initialized) return;
    ISteamUserStats* steamUserStats = SteamUserStats();
    if (!steamUserStats) return;
    steamUserStats->SetAchievement(achievementId.toUtf8().constData());
    steamUserStats->StoreStats();
}

bool SteamIntegration::isAchievementUnlocked(const QString& achievementId) {
    if (!m_initialized) return false;
    ISteamUserStats* steamUserStats = SteamUserStats();
    if (!steamUserStats) return false;
    bool achieved = false;
    steamUserStats->GetAchievement(achievementId.toUtf8().constData(), &achieved);
    return achieved;
}

void SteamIntegration::lockAllAchievements() {
    if (!m_initialized) return;
    ISteamUserStats* steamUserStats = SteamUserStats();
    if (!steamUserStats) return;

    // List all achievement IDs to lock
    QStringList achievements = {
        "ACH_NO_HINT_EASY", "ACH_NO_HINT_MEDIUM", "ACH_NO_HINT_HARD",
        "ACH_SPEED_DEMON", "ACH_HINT_MASTER"
    };

    for (const QString& achievementId : achievements) {
        steamUserStats->ClearAchievement(achievementId.toUtf8().constData());
    }
    steamUserStats->StoreStats();
}
