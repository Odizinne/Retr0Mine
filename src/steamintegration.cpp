#include "steamintegration.h"
#include <QDebug>
#include <QSettings>

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
{
    // Read initial difficulty from settings
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();
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
    updatePlayerName();

    // Initial rich presence update
    updateRichPresence();

    return true;
}

void SteamIntegration::shutdown()
{
    if (m_initialized) {
        ISteamFriends* steamFriends = SteamFriends();
        if (steamFriends) {
            steamFriends->ClearRichPresence();
        }
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

bool SteamIntegration::isAchievementUnlocked(const QString &achievementId) const
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

bool SteamIntegration::isRunningOnDeck() const
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

void SteamIntegration::updatePlayerName()
{
    if (!m_initialized)
        return;
    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return;
    QString newName = QString::fromUtf8(steamFriends->GetPersonaName());
    if (m_playerName != newName) {
        m_playerName = newName;
        emit playerNameChanged();
    }
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

// Rich presence related methods
void SteamIntegration::setDifficulty(int difficulty)
{
    if (m_difficulty != difficulty) {
        m_difficulty = difficulty;

        // Also update the settings so it persists
        QSettings settings("Odizinne", "Retr0Mine");
        settings.setValue("difficulty", difficulty);

        updateRichPresence();
    }
}

QString SteamIntegration::getDifficultyString() const
{
    QString language = getSteamUILanguage();

    if (language.toLower() == "french") {
        switch (m_difficulty) {
        case 0: return "Facile";
        case 1: return "Moyen";
        case 2: return "Difficile";
        case 3: return "Retr0";
        case 4: return "Personnalisé";
        default: return "Inconnu";
        }
    } else {
        switch (m_difficulty) {
        case 0: return "Easy";
        case 1: return "Medium";
        case 2: return "Hard";
        case 3: return "Retr0";
        case 4: return "Custom";
        default: return "Unknown";
        }
    }
}

void SteamIntegration::updateRichPresence()
{
    if (!m_initialized) {
        return;
    }

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends) {
        qDebug() << "Rich Presence update failed: Could not get SteamFriends interface";
        return;
    }

    steamFriends->SetRichPresence("difficulty", getDifficultyString().toUtf8().constData());
    steamFriends->SetRichPresence("steam_display", "#PlayingDifficulty");
}
