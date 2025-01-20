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
#ifdef _WIN32
    if (m_initialized) return true;
    if (!SteamAPI_Init()) {
        qWarning() << "Failed to initialize Steam API";
        return false;
    }
    m_initialized = true;
    return true;
#else
    return false;
#endif
}

void SteamIntegration::shutdown() {
#ifdef _WIN32
    if (m_initialized) {
        SteamAPI_Shutdown();
        m_initialized = false;
    }
#endif
}

void SteamIntegration::unlockAchievement(const QString& achievementId) {
#ifdef _WIN32
    if (!m_initialized) return;
    ISteamUserStats* steamUserStats = SteamUserStats();
    if (!steamUserStats) return;
    steamUserStats->SetAchievement(achievementId.toUtf8().constData());
    steamUserStats->StoreStats();
#endif
}

bool SteamIntegration::isAchievementUnlocked(const QString& achievementId) {
#ifdef _WIN32
    if (!m_initialized) return false;
    ISteamUserStats* steamUserStats = SteamUserStats();
    if (!steamUserStats) return false;
    bool achieved = false;
    steamUserStats->GetAchievement(achievementId.toUtf8().constData(), &achieved);
    return achieved;
#else
    return false;
#endif
}
