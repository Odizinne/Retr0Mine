#include <QDebug>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCoreApplication>
#include <QBuffer>
#include <QImage>
#include <QThread>
#include <QPainter>
#include <QPainterPath>
#include <QElapsedTimer>
#include <QDateTime>
#include <steam_api.h>
#include "steamintegration.h"

#define STEAM_DEBUG(msg) if (SteamIntegration::debugLoggingEnabled) qDebug() << "SteamIntegration: " << msg
bool SteamIntegration::debugLoggingEnabled = false;

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
    , m_inMultiplayerGame(false)
    , m_isHost(false)
    , m_isConnecting(false)
    , m_lobbyReady(false)
    , m_p2pInitialized(false)
    , m_connectionState(Disconnected)
    , m_lastMessageTime(0)
    , m_pingTime(0)
    , m_lastPingSent(0)
    , m_missedHeartbeats(0)
    , m_connectionCheckFailCount(0)
    , m_attemptingReconnection(false)
    , m_reconnectionAttempts(0)
{
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();

    // Set up network timers
    connect(&m_p2pInitTimer, &QTimer::timeout, this, &SteamIntegration::sendP2PInitPing);
    connect(&m_networkTimer, &QTimer::timeout, this, &SteamIntegration::processNetworkMessages);
    connect(&m_connectionHealthTimer, &QTimer::timeout, this, &SteamIntegration::checkConnectionHealth);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &SteamIntegration::sendHeartbeat);
    connect(&m_reconnectionTimer, &QTimer::timeout, this, &SteamIntegration::tryReconnect);

    // Create a regular callback timer
    QTimer* callbackTimer = new QTimer(this);
    connect(callbackTimer, &QTimer::timeout, this, &SteamIntegration::runCallbacks);
    callbackTimer->start(100);

    // Configure timers
    m_networkTimer.setInterval(50);     // Process network messages frequently
    m_heartbeatTimer.setInterval(HEARTBEAT_INTERVAL);
    m_connectionHealthTimer.setInterval(5000);  // Check connection every 5 seconds
    m_reconnectionTimer.setInterval(3000);      // Try reconnection every 3 seconds
}

SteamIntegration::~SteamIntegration()
{
    if (m_initialized) {
        if (m_inMultiplayerGame || m_connectedPlayerId.IsValid()) {
            cleanupMultiplayerSession(true);
        }

        shutdown();
    }
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
    updateRichPresence();

    return true;
}

void SteamIntegration::shutdown()
{
    if (m_initialized) {
        // Stop all network-related timers
        m_networkTimer.stop();
        m_p2pInitTimer.stop();
        m_heartbeatTimer.stop();
        m_connectionHealthTimer.stop();
        m_reconnectionTimer.stop();

        // Close P2P sessions
        ISteamNetworking* steamNet = SteamNetworking();
        if (steamNet && m_connectedPlayerId.IsValid()) {
            steamNet->CloseP2PSessionWithUser(m_connectedPlayerId);
            SteamAPI_RunCallbacks();
        }

        // Leave lobbies
        if (m_currentLobbyId.IsValid()) {
            SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
            SteamAPI_RunCallbacks();
        }

        // Clear rich presence
        ISteamFriends* steamFriends = SteamFriends();
        if (steamFriends) {
            steamFriends->ClearRichPresence();
        }

        SteamAPI_RunCallbacks();
        SteamAPI_Shutdown();
        m_initialized = false;
    }
}

void SteamIntegration::cleanupMultiplayerSession(bool isShuttingDown)
{
    // Stop network-related timers
    m_networkTimer.stop();
    m_p2pInitTimer.stop();
    m_heartbeatTimer.stop();
    m_connectionHealthTimer.stop();
    m_reconnectionTimer.stop();

    // If still initialized, close P2P sessions
    if (m_initialized && m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Closing P2P session with:" << m_connectedPlayerId.ConvertToUint64());
        SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
        SteamAPI_RunCallbacks();
    }

    // If still in a multiplayer game, leave the lobby
    if (m_initialized && m_inMultiplayerGame && m_currentLobbyId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Leaving lobby:" << m_currentLobbyId.ConvertToUint64());
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
        SteamAPI_RunCallbacks();
    }

    // Reset all multiplayer state
    m_inMultiplayerGame = false;
    m_isHost = false;
    m_lobbyReady = false;
    m_p2pInitialized = false;
    m_isConnecting = false;
    m_attemptingReconnection = false;
    m_reconnectionAttempts = 0;
    m_currentLobbyId = CSteamID();
    m_connectedPlayerId = CSteamID();
    m_connectedPlayerName = "";
    m_missedHeartbeats = 0;

    // Update connection state
    updateConnectionState(Disconnected);

    // Update rich presence and run callbacks if not shutting down
    if (m_initialized && !isShuttingDown) {
        updateRichPresence();
        SteamAPI_RunCallbacks();
    }

    // Emit signals to notify QML if not shutting down
    if (!isShuttingDown) {
        emit multiplayerStatusChanged();
        emit hostStatusChanged();
        emit lobbyReadyChanged();
        emit connectedPlayerChanged();
        emit canInviteFriendChanged();
        emit p2pInitialized();
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

void SteamIntegration::setDifficulty(int difficulty)
{
    if (m_p2pInitialized) return;
    if (m_difficulty != difficulty) {
        m_difficulty = difficulty;
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
        STEAM_DEBUG("Rich Presence update failed: Could not get SteamFriends interface");
        return;
    }

    if (m_inMultiplayerGame && m_p2pInitialized) {
        steamFriends->SetRichPresence("status", "Playing with friend");
        steamFriends->SetRichPresence("steam_display", "#PlayingCoopGame");
    } else {
        steamFriends->SetRichPresence("difficulty", getDifficultyString().toUtf8().constData());
        steamFriends->SetRichPresence("steam_display", "#PlayingDifficulty");
    }
}

void SteamIntegration::runCallbacks()
{
    if (m_initialized) {
        SteamAPI_RunCallbacks();
    }
}

// In the updateConnectionState method:
void SteamIntegration::updateConnectionState(ConnectionState newState)
{
    if (m_connectionState != newState) {
        ConnectionState oldState = m_connectionState;
        m_connectionState = newState;

        STEAM_DEBUG("SteamIntegration: Connection state changed from"
                 << oldState << "to" << newState);

        // Start or stop heartbeat based on connection state
        if (newState == Connected) {
            // Reset heartbeat tracking
            m_missedHeartbeats = 0;
            m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();

            // Ensure heartbeat is running
            if (!m_heartbeatTimer.isActive()) {
                m_heartbeatTimer.start();
            }

            // Take an initial ping measurement
            measurePing();
        }
        else if (newState == Disconnected) {
            // Stop heartbeat when disconnected
            m_heartbeatTimer.stop();

            // Reset ping time
            m_pingTime = 0;
            emit pingTimeChanged(m_pingTime);
        }

        emit connectionStateChanged(newState);
    }
}

void SteamIntegration::createLobby()
{
    STEAM_DEBUG("SteamIntegration: Creating lobby...");
    if (!m_initialized) {
        STEAM_DEBUG("SteamIntegration: Cannot create lobby - Steam not initialized");
        emit connectionFailed("Steam not initialized");
        return;
    }

    if (m_inMultiplayerGame) {
        STEAM_DEBUG("SteamIntegration: Cannot create lobby - Already in multiplayer game");
        emit connectionFailed("Already in multiplayer game");
        return;
    }

    // We're creating a lobby for 2 players (host + 1 friend)
    SteamAPICall_t apiCall = SteamMatchmaking()->CreateLobby(k_ELobbyTypePrivate, 2);

    if (apiCall == k_uAPICallInvalid) {
        STEAM_DEBUG("SteamIntegration: CreateLobby API call failed");
        emit connectionFailed("Failed to create Steam API call");
        return;
    }

    // Register the callback for this specific API call
    m_lobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnLobbyCreated);

    // Update state and notify UI
    m_isConnecting = true;
    updateConnectionState(Connecting);
    emit connectingStatusChanged();
}

void SteamIntegration::OnLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure)
{
    // Reset connecting flag
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        // Handle lobby creation failure
        QString errorMessage = bIOFailure ?
                                   "I/O Failure" :
                                   QString("Error %1").arg(pCallback->m_eResult);

        STEAM_DEBUG("SteamIntegration: Lobby creation failed with error:" << errorMessage);
        updateConnectionState(Disconnected);
        emit connectionFailed("Failed to create lobby (" + errorMessage + ")");
        return;
    }

    // Lobby created successfully
    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    STEAM_DEBUG("SteamIntegration: Lobby created with ID:" << m_currentLobbyId.ConvertToUint64());

    // Update state for host mode
    m_isHost = true;
    m_inMultiplayerGame = true;

    // Set lobby data (game name, version, etc.)
    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "game", "Retr0Mine");
    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "version", "1.0");

    // Start network processing
    m_networkTimer.start();

    // Update connection state
    updateConnectionState(Connected);

    // Notify UI
    emit hostStatusChanged();
    emit multiplayerStatusChanged();
    emit canInviteFriendChanged();
    emit connectionSucceeded();

    // Update rich presence
    updateRichPresence();
}

QStringList SteamIntegration::getOnlineFriends()
{
    QStringList friendList;
    if (!m_initialized)
        return friendList;

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return friendList;

    int friendCount = steamFriends->GetFriendCount(k_EFriendFlagImmediate);
    for (int i = 0; i < friendCount; i++) {
        CSteamID friendId = steamFriends->GetFriendByIndex(i, k_EFriendFlagImmediate);
        if (steamFriends->GetFriendPersonaState(friendId) != k_EPersonaStateOffline) {
            QString name = QString::fromUtf8(steamFriends->GetFriendPersonaName(friendId));
            QString id = QString::number(friendId.ConvertToUint64());

            int avatarHandle = steamFriends->GetMediumFriendAvatar(friendId);
            friendList.append(name + ":" + id + ":" + QString::number(avatarHandle));
        }
    }

    return friendList;
}

QString SteamIntegration::getAvatarImageForHandle(int handle)
{
    if (!m_initialized || handle == 0)
        return QString();
    ISteamUtils* steamUtils = SteamUtils();
    if (!steamUtils)
        return QString();
    uint32 width, height;
    if (!steamUtils->GetImageSize(handle, &width, &height) || width == 0 || height == 0)
        return QString();
    QByteArray imageData(width * height * 4, 0);
    if (!steamUtils->GetImageRGBA(handle, reinterpret_cast<uint8*>(imageData.data()), imageData.size()))
        return QString();

    // Convert the RGBA data to a QImage
    QImage image(reinterpret_cast<const uchar*>(imageData.data()), width, height, QImage::Format_RGBA8888);

    // Resize the image to 24x24
    QImage resizedImage = image.scaled(24, 24, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    // Check settings for style index
    QSettings settings("Odizinne", "Retr0Mine");
    bool shouldRound = (settings.value("themeIndex").toInt() == 0);

    QImage result;

    if (shouldRound) {
        // Create a rounded version of the resized image
        QImage rounded(24, 24, QImage::Format_ARGB32_Premultiplied);
        rounded.fill(Qt::transparent);

        QPainter painter(&rounded);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

        // Center the image if aspect ratio was preserved
        int x = (24 - resizedImage.width()) / 2;
        int y = (24 - resizedImage.height()) / 2;

        QPainterPath path;
        path.addRoundedRect(0, 0, 24, 24, 4, 4);
        painter.setClipPath(path);
        painter.drawImage(x, y, resizedImage);
        painter.end();

        result = rounded;
    } else {
        // Just use the resized image without rounding
        if (resizedImage.width() != 24 || resizedImage.height() != 24) {
            // Create a background for centering if needed
            QImage centered(24, 24, QImage::Format_ARGB32_Premultiplied);
            centered.fill(Qt::transparent);

            QPainter painter(&centered);

            // Center the image if aspect ratio was preserved
            int x = (24 - resizedImage.width()) / 2;
            int y = (24 - resizedImage.height()) / 2;

            painter.drawImage(x, y, resizedImage);
            painter.end();

            result = centered;
        } else {
            result = resizedImage;
        }
    }

    // Convert to PNG and then to base64
    QByteArray pngData;
    QBuffer buffer(&pngData);
    buffer.open(QIODevice::WriteOnly);
    result.save(&buffer, "PNG");
    buffer.close();

    // Create data URL
    return QString("data:image/png;base64,") + pngData.toBase64();
}

void SteamIntegration::inviteFriend(const QString& friendId)
{
    STEAM_DEBUG("SteamIntegration: Inviting friend:" << friendId);
    if (!m_initialized || !m_inMultiplayerGame || !m_isHost) {
        STEAM_DEBUG("SteamIntegration: Cannot invite - not initialized, not in game, or not host");
        return;
    }

    CSteamID steamFriendId(friendId.toULongLong());
    if (steamFriendId.IsValid() && m_currentLobbyId.IsValid()) {
        SteamMatchmaking()->InviteUserToLobby(m_currentLobbyId, steamFriendId);
        STEAM_DEBUG("SteamIntegration: Invitation sent to:" << friendId);
    }
}

void SteamIntegration::acceptInvite(const QString& lobbyId)
{
    STEAM_DEBUG("SteamIntegration: Accepting invite to lobby:" << lobbyId);
    if (!m_initialized) {
        STEAM_DEBUG("SteamIntegration: Cannot accept invite - Steam not initialized");
        emit connectionFailed("Steam not initialized");
        return;
    }

    if (m_inMultiplayerGame) {
        STEAM_DEBUG("SteamIntegration: Cannot accept invite - Already in a game");
        emit connectionFailed("Already in a multiplayer game");
        return;
    }

    CSteamID steamLobbyId(lobbyId.toULongLong());
    if (steamLobbyId.IsValid()) {
        // Update state
        m_isConnecting = true;
        updateConnectionState(Connecting);
        emit connectingStatusChanged();

        // Join the lobby
        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(steamLobbyId);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);
        STEAM_DEBUG("SteamIntegration: Join lobby call made, waiting for callback");
    } else {
        STEAM_DEBUG("SteamIntegration: Invalid lobby ID:" << lobbyId);
        emit connectionFailed("Invalid lobby ID");
    }
}

void SteamIntegration::leaveLobby()
{
    STEAM_DEBUG("SteamIntegration: Leaving lobby");
    if (!m_initialized)
        return;

    // Send a disconnection message to the other player if connected
    if (m_p2pInitialized && m_connectedPlayerId.IsValid()) {
        sendSystemMessage("disconnect", {{"reason", "User left the game"}});
    }

    // Even if we think we're not in a multiplayer game, try to clean up
    // This helps with edge cases where the state got out of sync

    // If we have a valid lobby ID, try to leave it directly first
    if (m_currentLobbyId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Leaving lobby ID:" << m_currentLobbyId.ConvertToUint64());
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
    }

    // Then do thorough cleanup
    cleanupMultiplayerSession();
}

void SteamIntegration::OnLobbyEntered(LobbyEnter_t *pCallback, bool bIOFailure)
{
    STEAM_DEBUG("SteamIntegration: OnLobbyEntered callback received");

    // Reset connecting flag
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_EChatRoomEnterResponse != k_EChatRoomEnterResponseSuccess) {
        QString errorMessage;

        if (bIOFailure) {
            errorMessage = "I/O Failure";
        } else {
            switch (pCallback->m_EChatRoomEnterResponse) {
            case k_EChatRoomEnterResponseDoesntExist:
                errorMessage = "Lobby no longer exists";
                break;
            case k_EChatRoomEnterResponseNotAllowed:
            case k_EChatRoomEnterResponseBanned:
            case k_EChatRoomEnterResponseLimited:
                errorMessage = "You don't have permission to join this lobby";
                break;
            case k_EChatRoomEnterResponseFull:
                errorMessage = "Lobby is already full";
                break;
            case k_EChatRoomEnterResponseError:
            default:
                errorMessage = "Unknown error (" + QString::number(pCallback->m_EChatRoomEnterResponse) + ")";
                break;
            }
        }

        STEAM_DEBUG("SteamIntegration: Failed to enter lobby, error:" << errorMessage);
        updateConnectionState(Disconnected);
        emit connectionFailed(errorMessage);
        return;
    }

    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);

    // Check what type of lobby this is
    const char* lobbyType = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "lobby_type");
    const char* matchmade = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "matchmade");

    if (lobbyType && strcmp(lobbyType, "matchmaking") == 0) {
        // This is a matchmaking lobby
        STEAM_DEBUG("SteamIntegration: Joined matchmaking lobby");

        m_matchmakingLobbyId = m_currentLobbyId;
        m_inMatchmaking = true;
        m_inMultiplayerGame = false;
        updateConnectionState(Connected);

        // Set player metadata for matching
        char difficultyStr[2];
        snprintf(difficultyStr, sizeof(difficultyStr), "%d", m_selectedMatchmakingDifficulty);
        SteamMatchmaking()->SetLobbyMemberData(m_matchmakingLobbyId, "difficulty", difficultyStr);

        // Start checking for matches
        m_matchmakingTimer.setInterval(2000);
        m_matchmakingTimer.setSingleShot(false);
        m_matchmakingTimer.start();
        connect(&m_matchmakingTimer, &QTimer::timeout, this, &SteamIntegration::checkForMatches);

        // Update queue counts
        refreshQueueCounts();

        emit matchmakingStatusChanged();
        emit connectionSucceeded();

    } else if (matchmade && strcmp(matchmade, "1") == 0) {
        // This is a matchmade game lobby
        STEAM_DEBUG("SteamIntegration: Joined matchmade game lobby");

        m_inMatchmaking = false;
        m_inMultiplayerGame = true;

        // Determine if we're the host
        CSteamID lobbyOwner = SteamMatchmaking()->GetLobbyOwner(m_currentLobbyId);
        m_isHost = (lobbyOwner == SteamUser()->GetSteamID());

        STEAM_DEBUG("SteamIntegration: Matchmade game lobby, host status:" << m_isHost);

        // If we're not the host, the lobby owner is our connected player
        if (!m_isHost) {
            m_connectedPlayerId = lobbyOwner;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(lobbyOwner);
            emit connectedPlayerChanged();

            startP2PInitialization();
        }

        // Start the network timer
        m_networkTimer.start();

        // Update connection state
        updateConnectionState(Connected);

        // Get the difficulty from the lobby
        const char* difficultyStr = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "difficulty");
        if (difficultyStr) {
            int difficulty = atoi(difficultyStr);
            m_selectedMatchmakingDifficulty = difficulty;
            emit selectedDifficultyChanged();

            // Update game settings to match the difficulty
            m_difficulty = difficulty;
            updateRichPresence();
        }

        emit matchmakingStatusChanged();
        emit hostStatusChanged();
        emit multiplayerStatusChanged();
        emit canInviteFriendChanged();
        emit connectionSucceeded();

    } else {
        // This is a regular game lobby
        STEAM_DEBUG("SteamIntegration: Joined regular game lobby");

        m_inMultiplayerGame = true;

        // Determine if we're the host
        CSteamID lobbyOwner = SteamMatchmaking()->GetLobbyOwner(m_currentLobbyId);
        m_isHost = (lobbyOwner == SteamUser()->GetSteamID());

        STEAM_DEBUG("SteamIntegration: Joined lobby, host status:" << m_isHost);

        // If we're not the host, the lobby owner is our connected player
        if (!m_isHost) {
            m_connectedPlayerId = lobbyOwner;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(lobbyOwner);
            emit connectedPlayerChanged();

            startP2PInitialization();
        }

        // Start network message processing
        m_networkTimer.start();

        // Update connection state
        updateConnectionState(Connected);

        // Notify UI
        emit multiplayerStatusChanged();
        emit hostStatusChanged();
        emit canInviteFriendChanged();
        emit connectionSucceeded();

        // Update rich presence
        updateRichPresence();
    }

    STEAM_DEBUG("SteamIntegration: Lobby join complete");
}

void SteamIntegration::OnLobbyDataUpdate(LobbyDataUpdate_t *pCallback)
{
    // If this update is for our matchmaking lobby
    if (m_inMatchmaking && m_matchmakingLobbyId.IsValid() &&
        m_matchmakingLobbyId.ConvertToUint64() == pCallback->m_ulSteamIDLobby) {

        // Check if there's a game lobby to join
        const char* gameLobbyIdStr = SteamMatchmaking()->GetLobbyData(m_matchmakingLobbyId, "game_lobby_id");
        const char* targetPlayerIdStr = SteamMatchmaking()->GetLobbyData(m_matchmakingLobbyId, "target_player_id");

        if (gameLobbyIdStr && targetPlayerIdStr && strlen(gameLobbyIdStr) > 0) {
            CSteamID targetPlayerId(strtoull(targetPlayerIdStr, nullptr, 10));

            // Check if we're the targeted player
            if (targetPlayerId == SteamUser()->GetSteamID()) {
                CSteamID gameLobbyId(strtoull(gameLobbyIdStr, nullptr, 10));
                STEAM_DEBUG("Auto-joining game lobby:" << gameLobbyId.ConvertToUint64());

                // Stop matchmaking
                m_matchmakingTimer.stop();
                m_inMatchmaking = false;
                emit matchmakingStatusChanged();

                // Join the game lobby directly
                m_isConnecting = true;
                emit connectingStatusChanged();

                SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(gameLobbyId);
                m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

                // Leave the matchmaking lobby
                SteamMatchmaking()->LeaveLobby(m_matchmakingLobbyId);
                m_matchmakingLobbyId = CSteamID();

                return; // We're joining a game lobby, no need to check further
            }
        }
    }

    // Regular lobby data handling for game lobbies
    if (m_currentLobbyId.IsValid() && m_currentLobbyId.ConvertToUint64() == pCallback->m_ulSteamIDLobby) {
        // Check if the game is ready to start
        const char* gameReadyValue = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "game_ready");
        if (gameReadyValue && QString(gameReadyValue) == "1") {
            if (!m_lobbyReady) {
                m_lobbyReady = true;
                emit lobbyReadyChanged();
                STEAM_DEBUG("SteamIntegration: Lobby marked as ready");
            }
        }
    }
}

void SteamIntegration::OnLobbyChatUpdate(LobbyChatUpdate_t *pCallback)
{
    // Handle player join/leave events
    STEAM_DEBUG("SteamIntegration: Lobby chat update received");

    // Check if this update is for one of our lobbies
    bool isCurrentLobby = (pCallback->m_ulSteamIDLobby == m_currentLobbyId.ConvertToUint64());
    bool isMatchmakingLobby = (pCallback->m_ulSteamIDLobby == m_matchmakingLobbyId.ConvertToUint64());

    if (!isCurrentLobby && !isMatchmakingLobby) {
        return; // Not for any of our lobbies
    }

    STEAM_DEBUG("SteamIntegration: Lobby chat update for "
             << (isMatchmakingLobby ? "matchmaking" : "game")
             << " lobby, change flags:" << pCallback->m_rgfChatMemberStateChange);

    // Check the chat member change flags
    if (pCallback->m_rgfChatMemberStateChange & k_EChatMemberStateChangeEntered) {
        // A player joined the lobby
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (isMatchmakingLobby) {
            // For matchmaking lobby, just update queue counts
            STEAM_DEBUG("SteamIntegration: Player" << playerId.ConvertToUint64()
                     << "joined matchmaking lobby, updating queue counts");
            refreshQueueCounts();

        } else if (m_isHost && playerId != SteamUser()->GetSteamID()) {
            // If we're the host and someone else joined our game lobby, that's our connected player
            STEAM_DEBUG("SteamIntegration: Player joined our hosted game lobby");

            m_connectedPlayerId = playerId;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(playerId);
            emit connectedPlayerChanged();

            // Now that we have a connected player, set lobby as ready
            if (!m_lobbyReady) {
                SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "game_ready", "1");
                m_lobbyReady = true;
                emit lobbyReadyChanged();
            }

            // Start P2P initialization
            startP2PInitialization();

            STEAM_DEBUG("SteamIntegration: Player joined lobby:" << m_connectedPlayerName);
        }
    }
    else if (pCallback->m_rgfChatMemberStateChange & (k_EChatMemberStateChangeLeft | k_EChatMemberStateChangeDisconnected)) {
        // A player left the lobby
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (isMatchmakingLobby) {
            // For matchmaking lobby, just update queue counts
            STEAM_DEBUG("SteamIntegration: Player" << playerId.ConvertToUint64()
                     << "left matchmaking lobby, updating queue counts");
            refreshQueueCounts();

        } else if (playerId == m_connectedPlayerId) {
            // Our connected player left the game lobby
            STEAM_DEBUG("SteamIntegration: Connected player left game lobby");

            // Save the player name for notification
            QString playerName = m_connectedPlayerName;

            // Reset connection state
            updateConnectionState(Disconnected);

            // Clean up multiplayer session
            cleanupMultiplayerSession();

            // Notify the UI about the disconnection
            emit notifyConnectionLost(playerName);
        }
    }
}

void SteamIntegration::OnP2PSessionRequest(P2PSessionRequest_t *pCallback)
{
    // Accept P2P connections from lobby members
    CSteamID requestorId = pCallback->m_steamIDRemote;
    STEAM_DEBUG("SteamIntegration: P2P session request from:" << requestorId.ConvertToUint64());

    // Only accept connections from players in our lobby
    if (m_currentLobbyId.IsValid()) {
        int memberCount = SteamMatchmaking()->GetNumLobbyMembers(m_currentLobbyId);
        for (int i = 0; i < memberCount; i++) {
            CSteamID memberId = SteamMatchmaking()->GetLobbyMemberByIndex(m_currentLobbyId, i);
            if (memberId == requestorId) {
                SteamNetworking()->AcceptP2PSessionWithUser(requestorId);
                STEAM_DEBUG("SteamIntegration: P2P session accepted");

                // If we're in the middle of a reconnection attempt and this is our player, update state
                if (m_attemptingReconnection && requestorId == m_connectedPlayerId) {
                    STEAM_DEBUG("SteamIntegration: Reconnection request accepted");
                }

                return;
            }
        }
    }

    // For reconnection attempts, check if this is the connected player ID
    if (m_attemptingReconnection && requestorId == m_connectedPlayerId) {
        SteamNetworking()->AcceptP2PSessionWithUser(requestorId);
        STEAM_DEBUG("SteamIntegration: Reconnection P2P session accepted");
        return;
    }

    STEAM_DEBUG("SteamIntegration: P2P session rejected - user not in lobby");
}

void SteamIntegration::OnP2PSessionConnectFail(P2PSessionConnectFail_t *pCallback)
{
    // Handle connection failures
    CSteamID failedId = pCallback->m_steamIDRemote;
    STEAM_DEBUG("SteamIntegration: P2P session connect failed with:" << failedId.ConvertToUint64());

    if (failedId == m_connectedPlayerId) {
        QString errorReason = "Connection failed (error " + QString::number(pCallback->m_eP2PSessionError) + ")";
        STEAM_DEBUG("SteamIntegration: Connection failed with connected player:" << errorReason);

        // If we're actively trying to reconnect, handle retry logic
        if (m_attemptingReconnection) {
            m_reconnectionAttempts++;

            if (m_reconnectionAttempts >= MAX_RECONNECTION_ATTEMPTS) {
                STEAM_DEBUG("SteamIntegration: Maximum reconnection attempts reached");
                updateConnectionState(Disconnected);
                m_attemptingReconnection = false;
                emit reconnectionFailed();
                cleanupMultiplayerSession();
                emit notifyConnectionLost(m_connectedPlayerName);
            } else {
                STEAM_DEBUG("SteamIntegration: Reconnection attempt" << m_reconnectionAttempts
                         << "failed, retrying...");
                // Next attempt will happen automatically via the reconnection timer
            }
        } else {
            // Normal connection failure
            updateConnectionState(Disconnected);
            emit connectionFailed(errorReason);
            cleanupMultiplayerSession();
        }
    }
}

void SteamIntegration::OnGameLobbyJoinRequested(GameLobbyJoinRequested_t *pCallback)
{
    // This callback is triggered when the player accepts a lobby invite from the Steam overlay
    uint64 lobbyID = pCallback->m_steamIDLobby.ConvertToUint64();
    STEAM_DEBUG("SteamIntegration: Game lobby join requested for lobby:" << lobbyID);

    if (m_inMultiplayerGame) {
        // Already in a game, need to leave first
        STEAM_DEBUG("SteamIntegration: Already in a game, leaving first");
        leaveLobby();

        // Give a little time for cleanup before joining
        QTimer::singleShot(500, [this, lobbyID]() {
            // Join the requested lobby after cleanup
            m_isConnecting = true;
            updateConnectionState(Connecting);
            emit connectingStatusChanged();

            SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(CSteamID(lobbyID));
            m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

            STEAM_DEBUG("SteamIntegration: Join requested lobby call made after leaving previous game");
        });
    } else {
        // Join the requested lobby immediately
        m_isConnecting = true;
        updateConnectionState(Connecting);
        emit connectingStatusChanged();

        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(pCallback->m_steamIDLobby);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

        STEAM_DEBUG("SteamIntegration: Join requested lobby call made, waiting for callback");
    }
}

void SteamIntegration::processNetworkMessages()
{
    if (!m_initialized || (!m_inMultiplayerGame && !m_attemptingReconnection))
        return;

    uint32 msgSize;
    // Process all available packets in the queue
    while (SteamNetworking()->IsP2PPacketAvailable(&msgSize)) {
        // Only skip truly oversized packets (16KB is a reasonable limit)
        if (msgSize > 16384) {
            STEAM_DEBUG("SteamIntegration: Skipping oversized packet:" << msgSize);

            // Read and discard the packet instead of leaving it in the queue
            QByteArray discardBuffer(msgSize, 0);
            CSteamID senderId;
            SteamNetworking()->ReadP2PPacket(discardBuffer.data(), msgSize, nullptr, &senderId);
            continue;
        }

        QByteArray buffer(msgSize, 0);
        CSteamID senderId;

        if (SteamNetworking()->ReadP2PPacket(buffer.data(), msgSize, &msgSize, &senderId)) {
            // Accept all packets with at least 1 byte (the message type)
            if (msgSize < 1) {
                STEAM_DEBUG("SteamIntegration: Empty packet received, skipping");
                continue;
            }

            // Update timestamp for last received message
            m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();

            // Process message based on type
            char messageType = buffer[0];
            QByteArray messageData;

            // Only extract message data if there's data beyond the header
            if (msgSize > 1) {
                messageData = buffer.mid(1);
            }

            // *** CRITICAL FIX: Always mark P2P as initialized when receiving any valid message ***
            if (!m_p2pInitialized) {
                STEAM_DEBUG("SteamIntegration: P2P connection established on message receipt!");
                m_p2pInitialized = true;
                updateConnectionState(Connected);
                emit p2pInitialized();

                // If we were reconnecting, stop that process
                if (m_attemptingReconnection) {
                    m_attemptingReconnection = false;
                    m_reconnectionAttempts = 0;
                    m_reconnectionTimer.stop();
                    emit reconnectionSucceeded();
                }

                // Start the heartbeat
                m_missedHeartbeats = 0;
                m_heartbeatTimer.start();
                m_connectionHealthTimer.start();

                // Update rich presence
                updateRichPresence();
            }

            // Reset heartbeat counters on any message
            m_missedHeartbeats = 0;

            // If connection was unstable but messages are flowing again,
            // mark as connected
            if (m_connectionState == Unstable) {
                updateConnectionState(Connected);
            }

            // Process different message types
            switch (messageType) {
            case 'P': // Ping/Pong messages (can be very small)
                if (messageData.startsWith("PING")) {
                    // Respond with PONG
                    QByteArray response;
                    response.append('P');
                    response.append("PONG");
                    SteamNetworking()->SendP2PPacket(
                        senderId,
                        response.constData(),
                        response.size(),
                        k_EP2PSendReliable
                        );
                } else if (messageData.startsWith("PONG")) {
                    // Calculate ping time if we sent a ping
                    if (m_lastPingSent > 0) {
                        int now = QDateTime::currentMSecsSinceEpoch();
                        m_pingTime = now - m_lastPingSent;
                        m_lastPingSent = 0;

                        // If ping is too high, emit a warning signal
                        if (m_pingTime > 500 && m_p2pInitialized && m_connectionState == Connected) {
                            updateConnectionState(Unstable);
                            emit connectionUnstable();
                        }

                        emit pingTimeChanged(m_pingTime);
                    }
                }
                break;

            case 'H': // Heartbeat (should be just 1 byte)
                // Heartbeat receipt already reset the missed heartbeats counter above
                // Nothing more to do for a heartbeat message
                break;

            case 'S': // System message
                if (messageData.size() > 0) {
                    try {
                        handleSystemMessage(messageData);
                    } catch (const std::exception& e) {
                        STEAM_DEBUG("Error handling system message:" << e.what());
                    }
                }
                break;

            case 'A': // Game action
                if (messageData.size() > 0) {
                    try {
                        handleGameAction(messageData);
                    } catch (const std::exception& e) {
                        STEAM_DEBUG("Error handling game action:" << e.what());
                    }
                }
                break;

            case 'D': // Game state data
                if (messageData.size() > 0) {
                    try {
                        handleGameState(messageData);
                    } catch (const std::exception& e) {
                        STEAM_DEBUG("Error handling game state:" << e.what());
                    }
                }
                break;

            default:
                STEAM_DEBUG("SteamIntegration: Unknown message type:" << messageType
                         << "size:" << messageData.size());
                break;
            }
        } else {
            STEAM_DEBUG("SteamIntegration: Failed to read P2P packet");
        }
    }

    // Check if connection is healthy while processing messages
    static int messageLoopCounter = 0;
    messageLoopCounter++;

    // Every 10 message processing loops, perform a connection health check
    if (messageLoopCounter >= 10) {
        messageLoopCounter = 0;

        // If we're supposedly p2p connected but the connection state doesn't match,
        // fix the inconsistency
        if (m_p2pInitialized && m_connectionState != Connected && m_connectionState != Unstable) {
            STEAM_DEBUG("Fixing inconsistent connection state: p2pInitialized but state is"
                     << m_connectionState);
            updateConnectionState(Connected);
        }
    }
}

bool SteamIntegration::sendGameAction(const QString& actionType, const QVariant& parameter)
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Cannot send game action - not initialized, not in game, or no connected player");
        return false;
    }

    // Check connection state
    if (m_connectionState != Connected && m_connectionState != Unstable) {
        STEAM_DEBUG("SteamIntegration: Cannot send game action - connection not established");
        return false;
    }

    // Format depends on parameter type
    QByteArray data;
    data.append('A'); // Action header

    if (parameter.typeId() == QMetaType::QString) {
        // Handle string parameters (like chat messages)
        // Format: A|actionType|stringData
        QString stringParameter = parameter.toString();
        data.append(actionType.toUtf8());
        data.append('|');
        data.append(stringParameter.toUtf8());

        STEAM_DEBUG("SteamIntegration: Sending string action:" << actionType
                 << "with text:" << stringParameter.left(20) + (stringParameter.length() > 20 ? "..." : "")
                 << "to:" << m_connectedPlayerId.ConvertToUint64());
    } else {
        // Original behavior for number parameters
        // Format: A|actionType|cellIndex
        int cellIndex = parameter.toInt();
        data.append(actionType.toUtf8());
        data.append('|');
        data.append(QByteArray::number(cellIndex));

        STEAM_DEBUG("SteamIntegration: Sending game action:" << actionType
                 << "for cell:" << cellIndex << "to:" << m_connectedPlayerId.ConvertToUint64());
    }

    return SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}

bool SteamIntegration::sendGameState(const QVariantMap& gameState)
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Cannot send game state - not initialized, not in game, or no connected player");
        return false;
    }

    // Check connection state
    if (m_connectionState != Connected && m_connectionState != Unstable) {
        STEAM_DEBUG("SteamIntegration: Cannot send game state - connection not established");
        return false;
    }

    // Serialize the game state to JSON
    QJsonDocument doc = QJsonDocument::fromVariant(gameState);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    // Prepare packet: D + JSON data (changed from S to D for clarity with system messages)
    QByteArray packet;
    packet.append('D');
    packet.append(jsonData);

    // Only log the beginning of large packets to avoid spamming the console
    QString logData = jsonData.size() > 100 ?
                          QString(jsonData.left(100)) + "... (total size: " + QString::number(jsonData.size()) + ")" :
                          QString(jsonData);

    STEAM_DEBUG("SteamIntegration: Sending game state:" << logData
             << "to:" << m_connectedPlayerId.ConvertToUint64());

    return SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        packet.constData(),
        packet.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::handleGameAction(const QByteArray& data)
{
    // Parse action data
    int separatorPos = data.indexOf('|');
    if (separatorPos == -1) {
        STEAM_DEBUG("SteamIntegration: Invalid game action format");
        return;
    }

    QString actionType = QString::fromUtf8(data.left(separatorPos));
    QByteArray parameterData = data.mid(separatorPos + 1);

    // Try to convert to integer first
    bool isInt = false;
    int cellIndex = parameterData.toInt(&isInt);

    if (isInt) {
        // Handle numeric parameter
        STEAM_DEBUG("SteamIntegration: Received game action:" << actionType << "for cell:" << cellIndex;
        emit gameActionReceived(actionType, cellIndex));
    } else {
        // Handle string parameter (for chat messages)
        QString stringParam = QString::fromUtf8(parameterData);
        STEAM_DEBUG("SteamIntegration: Received string action:" << actionType
                 << "with text:" << stringParam.left(20) + (stringParam.length() > 20 ? "..." : ""));
        emit gameActionReceived(actionType, stringParam);
    }
}

void SteamIntegration::handleGameState(const QByteArray& data)
{
    // Parse JSON game state
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        STEAM_DEBUG("SteamIntegration: Invalid game state JSON:" << parseError.errorString());
        STEAM_DEBUG("Data snippet:" << data.left(100));
        return;
    }

    if (!doc.isObject()) {
        STEAM_DEBUG("SteamIntegration: Game state is not a JSON object");
        return;
    }

    QVariantMap gameState = doc.object().toVariantMap();

    // Log a summary of what was received
    QStringList keys = gameState.keys();
    STEAM_DEBUG("SteamIntegration: Received game state with keys:" << keys);

    emit gameStateReceived(gameState);
}

void SteamIntegration::handleSystemMessage(const QByteArray& data)
{
    // Parse system message JSON
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        STEAM_DEBUG("SteamIntegration: Invalid system message JSON:" << parseError.errorString());
        return;
    }

    if (!doc.isObject()) {
        STEAM_DEBUG("SteamIntegration: System message is not a JSON object");
        return;
    }

    QVariantMap message = doc.object().toVariantMap();
    QString type = message["type"].toString();

    STEAM_DEBUG("SteamIntegration: Received system message type:" << type);

    if (type == "disconnect") {
        // Other player is disconnecting gracefully
        QString reason = message["reason"].toString();
        STEAM_DEBUG("SteamIntegration: Received disconnect message, reason:" << reason);

        // Handle disconnection
        updateConnectionState(Disconnected);

        // Clean up multiplayer session
        cleanupMultiplayerSession();

        // Notify the UI
        emit notifyConnectionLost(m_connectedPlayerName);
    }
    else if (type == "reconnect_request") {
        // Other player is attempting to reconnect
        STEAM_DEBUG("SteamIntegration: Received reconnection request");

        // Send acknowledgment
        sendSystemMessage("reconnect_ack");

        // Mark as reconnecting
        updateConnectionState(Reconnecting);
    }
    else if (type == "reconnect_ack") {
        // Our reconnection request was acknowledged
        STEAM_DEBUG("SteamIntegration: Reconnection request acknowledged");

        // Start the heartbeat
        m_heartbeatTimer.start();
        m_connectionHealthTimer.start();

        // Update connection state
        updateConnectionState(Connected);

        // Mark reconnection as successful
        m_attemptingReconnection = false;
        m_reconnectionAttempts = 0;
        m_reconnectionTimer.stop();

        // Notify success
        emit reconnectionSucceeded();
    }
    else if (type == "ping_test") {
        // A ping test message - respond immediately with same timestamp
        QVariant timestamp = message["timestamp"];
        STEAM_DEBUG("SteamIntegration: Received ping test, echoing timestamp:" << timestamp.toLongLong());

        // Echo back the exact same timestamp
        QVariantMap responseData;
        responseData["timestamp"] = timestamp;
        sendSystemMessage("ping_response", responseData);
    }
    else if (type == "ping_response") {
        // Response to our ping test
        QVariant timestamp = message["timestamp"];
        if (timestamp.isValid()) {
            bool ok;
            qint64 sentTime = timestamp.toLongLong(&ok);
            if (ok) {
                qint64 now = QDateTime::currentMSecsSinceEpoch();
                m_pingTime = now - sentTime;

                STEAM_DEBUG("SteamIntegration: Ping time calculated:" << m_pingTime << "ms");

                // Emit signal to update UI
                emit pingTimeChanged(m_pingTime);

                // Update connection state if ping is high
                if (m_pingTime > 500 && m_connectionState == Connected) {
                    updateConnectionState(Unstable);
                    emit connectionUnstable();
                }
            }
        }
    }
}

void SteamIntegration::sendSystemMessage(const QString& type, const QVariantMap& data)
{
    if (!m_initialized || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Cannot send system message - not initialized or no connected player");
        return;
    }

    // Prepare system message
    QVariantMap message = data;
    message["type"] = type;

    // Serialize to JSON
    QJsonDocument doc = QJsonDocument::fromVariant(message);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    // Prepare packet: S + JSON data
    QByteArray packet;
    packet.append('S');
    packet.append(jsonData);

    STEAM_DEBUG("SteamIntegration: Sending system message type:" << type
             << "to:" << m_connectedPlayerId.ConvertToUint64());

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        packet.constData(),
        packet.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::sendP2PInitPing()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        m_p2pInitTimer.stop();
        return;
    }

    QByteArray data;
    data.append('P'); // P for Ping
    data.append("PING");

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}


void SteamIntegration::sendHeartbeat()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        m_heartbeatTimer.stop();
        return;
    }

    // Send a minimal heartbeat message - just a single byte
    char heartbeat = 'H';

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        &heartbeat,
        1,  // Just send one byte for heartbeats
        k_EP2PSendUnreliable // Use unreliable for heartbeats
        );

    // Every 5th heartbeat, measure ping
    static int heartbeatCounter = 0;
    heartbeatCounter = (heartbeatCounter + 1) % 5;

    if (heartbeatCounter == 0 && m_p2pInitialized) {
        measurePing();
    }
}

bool SteamIntegration::forcePing()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || !m_p2pInitialized) {
        return false;
    }

    // Record the time we sent the ping
    m_lastPingSent = QDateTime::currentMSecsSinceEpoch();

    // Send a ping message
    QByteArray data;
    data.append('P'); // P for Ping
    data.append("PING");

    return SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::checkConnectionHealth() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        // No need to check if we're not in a multiplayer game
        m_connectionHealthTimer.stop();
        return;
    }

    // First, check if the Steam P2P session is active
    P2PSessionState_t sessionState;
    bool hasSession = SteamNetworking()->GetP2PSessionState(m_connectedPlayerId, &sessionState);

    if (!hasSession || sessionState.m_bConnectionActive == 0) {
        m_connectionCheckFailCount++;
        STEAM_DEBUG("SteamIntegration: Steam session check failed" << m_connectionCheckFailCount << "times");

        if (m_connectionCheckFailCount >= MAX_CONNECTION_FAILURES) {
            STEAM_DEBUG("SteamIntegration: Connection lost according to Steam, attempting reconnection");
            if (m_connectionState == Connected) {
                updateConnectionState(Unstable);
                emit connectionUnstable();
            } else if (m_connectionState == Unstable) {
                requestReconnection();
            }
        }
        return;
    }

    // If we get here, the Steam session is active, so reset that failure counter
    m_connectionCheckFailCount = 0;

    // Now check if heartbeats are coming through
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    qint64 timeSinceLastMessage = now - m_lastMessageTime;

    // If it's been too long since any message was received
    if (m_p2pInitialized && timeSinceLastMessage > 15000) { // 15 seconds without any message
        STEAM_DEBUG("SteamIntegration: No messages received for" << timeSinceLastMessage << "ms");

        // If this happens repeatedly, mark the connection as unstable
        m_missedHeartbeats++;
        STEAM_DEBUG("SteamIntegration: Heartbeat timeout:" << m_missedHeartbeats);

        if (m_missedHeartbeats >= MAX_MISSED_HEARTBEATS) {
            if (m_connectionState == Connected) {
                STEAM_DEBUG("SteamIntegration: Too many missed heartbeats, connection unstable");
                updateConnectionState(Unstable);
                emit connectionUnstable();

                // Try to ping actively to test connection
                forcePing();
            } else if (m_connectionState == Unstable && timeSinceLastMessage > 30000) {
                // If we've been unstable for a while with no messages, try reconnecting
                STEAM_DEBUG("SteamIntegration: Connection stalled, attempting reconnection");
                requestReconnection();
            }
        }
    } else {
        // Messages are being received, reset missed heartbeats counter
        if (m_missedHeartbeats > 0) {
            m_missedHeartbeats = 0;

            // If we were in unstable state but communication is working again, go back to connected
            if (m_connectionState == Unstable) {
                STEAM_DEBUG("SteamIntegration: Connection recovered");
                updateConnectionState(Connected);
            }
        }
    }
}

void SteamIntegration::resetConnectionHealth()
{
    m_connectionCheckFailCount = 0;
    m_missedHeartbeats = 0;
    m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();
}

void SteamIntegration::requestReconnection()
{
    if (!m_initialized || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("SteamIntegration: Cannot request reconnection - not initialized or no connected player");
        return;
    }

    // Don't attempt reconnection if we're already disconnected
    if (m_connectionState == Disconnected) {
        STEAM_DEBUG("SteamIntegration: Already disconnected, cannot reconnect");
        return;
    }

    // Don't start a new reconnection if one is already in progress
    if (m_attemptingReconnection) {
        STEAM_DEBUG("SteamIntegration: Reconnection already in progress");
        return;
    }

    STEAM_DEBUG("SteamIntegration: Initiating reconnection process");

    // Update connection state
    updateConnectionState(Reconnecting);

    // Start reconnection attempt
    m_attemptingReconnection = true;
    m_reconnectionAttempts = 0;

    // First attempt immediately
    tryReconnect();

    // Start timer for subsequent attempts
    m_reconnectionTimer.start();
}

void SteamIntegration::tryReconnect()
{
    if (!m_initialized || !m_connectedPlayerId.IsValid() || !m_attemptingReconnection) {
        m_reconnectionTimer.stop();
        return;
    }

    m_reconnectionAttempts++;
    STEAM_DEBUG("SteamIntegration: Reconnection attempt" << m_reconnectionAttempts);

    if (m_reconnectionAttempts > MAX_RECONNECTION_ATTEMPTS) {
        STEAM_DEBUG("SteamIntegration: Maximum reconnection attempts reached");
        m_attemptingReconnection = false;
        m_reconnectionTimer.stop();
        updateConnectionState(Disconnected);
        emit reconnectionFailed();

        // Clean up and notify about disconnection
        cleanupMultiplayerSession();
        emit notifyConnectionLost(m_connectedPlayerName);
        return;
    }

    // Send a reconnection request
    sendSystemMessage("reconnect_request");

    // Also try to reinitialize the P2P connection
    SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
    SteamAPI_RunCallbacks();

    // Wait a moment before attempting to reconnect
    QTimer::singleShot(500, [this]() {
        if (m_attemptingReconnection) {
            m_p2pInitialized = false;
            startP2PInitialization();
        }
    });
}

void SteamIntegration::startP2PInitialization() {
    if (!m_initialized || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        return;
    }

    STEAM_DEBUG("SteamIntegration: Starting P2P initialization process");

    // Reset flags
    m_p2pInitialized = false;
    updateConnectionState(Connecting);
    m_missedHeartbeats = 0;

    // Start sending initialization pings
    m_p2pInitTimer.setInterval(500);
    m_p2pInitTimer.start();

    // Start health monitoring
    m_connectionHealthTimer.setInterval(5000);
    m_connectionHealthTimer.start();

    // Send initial ping
    sendP2PInitPing();
}

bool SteamIntegration::testConnection()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        return false;
    }

    // Check P2P session state
    P2PSessionState_t sessionState;
    bool hasSession = SteamNetworking()->GetP2PSessionState(m_connectedPlayerId, &sessionState);

    if (!hasSession || sessionState.m_bConnectionActive == 0) {
        STEAM_DEBUG("SteamIntegration: Connection test failed - no active session");
        return false;
    }

    // Send a test ping
    return forcePing();
}

// Matchmaking implementation
void SteamIntegration::enterMatchmaking(int difficulty)
{
    if (!m_initialized) {
        emit matchmakingError("Steam is not initialized");
        return;
    }

    if (m_inMatchmaking || m_inMultiplayerGame) {
        emit matchmakingError("Already in matchmaking or a multiplayer game");
        return;
    }

    // Validate difficulty (0=Easy, 1=Medium, 2=Hard, 3=Retr0)
    if (difficulty < 0 || difficulty > 3) {
        emit matchmakingError("Invalid difficulty selected");
        return;
    }

    m_selectedMatchmakingDifficulty = difficulty;
    emit selectedDifficultyChanged();

    // Try to find existing matchmaking lobby
    SteamMatchmaking()->RequestLobbyList();

    // Set a filter to find matchmaking lobbies
    SteamMatchmaking()->AddRequestLobbyListStringFilter(
        "lobby_type", "matchmaking", k_ELobbyComparisonEqual);

    // Request the lobby list
    SteamAPICall_t hSteamAPICall = SteamMatchmaking()->RequestLobbyList();
    m_lobbyMatchListCallback.Set(hSteamAPICall, this, &SteamIntegration::OnLobbyMatchList);

    m_isConnecting = true;
    emit connectingStatusChanged();
}

void SteamIntegration::OnLobbyMatchList(LobbyMatchList_t *pCallback, bool bIOFailure) {
    if (bIOFailure) {
        m_isConnecting = false;
        emit connectingStatusChanged();
        emit matchmakingError("Error retrieving matchmaking lobbies");
        return;
    }

    // Check if we found any matchmaking lobbies
    int lobbyCount = pCallback->m_nLobbiesMatching;
    CSteamID matchmakingLobbyId;
    bool foundMatchmakingLobby = false;

    STEAM_DEBUG("Found" << lobbyCount << "matchmaking lobbies");

    // Look for a matchmaking lobby
    for (int i = 0; i < lobbyCount; i++) {
        CSteamID lobbyId = SteamMatchmaking()->GetLobbyByIndex(i);
        const char* lobbyType = SteamMatchmaking()->GetLobbyData(lobbyId, "lobby_type");

        if (lobbyType && strcmp(lobbyType, "matchmaking") == 0) {
            matchmakingLobbyId = lobbyId;
            foundMatchmakingLobby = true;
            break;
        }
    }

    if (foundMatchmakingLobby) {
        // Join the existing matchmaking lobby
        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(matchmakingLobbyId);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);
    } else {
        // Create a new matchmaking lobby
        SteamAPICall_t apiCall = SteamMatchmaking()->CreateLobby(k_ELobbyTypePublic, 50); // Allow up to 50 players for matchmaking
        m_matchLobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnMatchmakingLobbyCreated);
    }
}

void SteamIntegration::OnMatchmakingLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure) {
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        emit matchmakingError("Failed to create matchmaking lobby");
        return;
    }

    m_matchmakingLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    STEAM_DEBUG("Created matchmaking lobby with ID:" << m_matchmakingLobbyId.ConvertToUint64());

    // Set lobby data
    SteamMatchmaking()->SetLobbyData(m_matchmakingLobbyId, "lobby_type", "matchmaking");
    SteamMatchmaking()->SetLobbyData(m_matchmakingLobbyId, "game", "Retr0Mine");
    SteamMatchmaking()->SetLobbyData(m_matchmakingLobbyId, "version", "1.0");

    // Set player metadata for matching
    char difficultyStr[2];
    snprintf(difficultyStr, sizeof(difficultyStr), "%d", m_selectedMatchmakingDifficulty);
    SteamMatchmaking()->SetLobbyMemberData(m_matchmakingLobbyId, "difficulty", difficultyStr);

    m_inMatchmaking = true;
    emit matchmakingStatusChanged();

    // Start checking for matches
    m_matchmakingTimer.setInterval(2000); // Check every 2 seconds
    m_matchmakingTimer.setSingleShot(false);
    m_matchmakingTimer.start();
    connect(&m_matchmakingTimer, &QTimer::timeout, this, &SteamIntegration::checkForMatches);

    // Update queue counts
    refreshQueueCounts();
}

void SteamIntegration::leaveMatchmaking() {
    if (!m_initialized || !m_inMatchmaking) {
        return;
    }

    // Stop the matchmaking timer
    m_matchmakingTimer.stop();

    // Leave the matchmaking lobby
    if (m_matchmakingLobbyId.IsValid()) {
        SteamMatchmaking()->LeaveLobby(m_matchmakingLobbyId);
        m_matchmakingLobbyId = CSteamID();
    }

    // Update state
    m_inMatchmaking = false;
    emit matchmakingStatusChanged();

    STEAM_DEBUG("Left matchmaking");
}

void SteamIntegration::refreshQueueCounts() {
    if (!m_initialized || !m_matchmakingLobbyId.IsValid()) {
        return;
    }

    // Reset counts
    int easyCount = 0;
    int mediumCount = 0;
    int hardCount = 0;
    int retr0Count = 0;

    // Count players by difficulty
    int memberCount = SteamMatchmaking()->GetNumLobbyMembers(m_matchmakingLobbyId);

    for (int i = 0; i < memberCount; i++) {
        CSteamID memberId = SteamMatchmaking()->GetLobbyMemberByIndex(m_matchmakingLobbyId, i);
        const char* difficultyStr = SteamMatchmaking()->GetLobbyMemberData(
            m_matchmakingLobbyId, memberId, "difficulty");

        if (!difficultyStr) {
            continue; // Skip players without difficulty set
        }

        int memberDifficulty = atoi(difficultyStr);

        switch (memberDifficulty) {
        case 0: easyCount++; break;
        case 1: mediumCount++; break;
        case 2: hardCount++; break;
        case 3: retr0Count++; break;
        }
    }

    // Update counts if changed
    bool changed = false;

    if (m_easyQueueCount != easyCount) {
        m_easyQueueCount = easyCount;
        changed = true;
    }

    if (m_mediumQueueCount != mediumCount) {
        m_mediumQueueCount = mediumCount;
        changed = true;
    }

    if (m_hardQueueCount != hardCount) {
        m_hardQueueCount = hardCount;
        changed = true;
    }

    if (m_retr0QueueCount != retr0Count) {
        m_retr0QueueCount = retr0Count;
        changed = true;
    }

    if (changed) {
        emit queueCountsChanged();
    }
}

void SteamIntegration::checkForMatches() {
    if (!m_initialized || !m_inMatchmaking || !m_matchmakingLobbyId.IsValid()) {
        m_matchmakingTimer.stop();
        return;
    }

    // Update queue counts first
    refreshQueueCounts();

    // Get the number of players in the lobby
    int memberCount = SteamMatchmaking()->GetNumLobbyMembers(m_matchmakingLobbyId);

    // Our own Steam ID
    CSteamID mySteamId = SteamUser()->GetSteamID();

    // Look for potential matches (players with the same difficulty)
    for (int i = 0; i < memberCount; i++) {
        CSteamID memberId = SteamMatchmaking()->GetLobbyMemberByIndex(m_matchmakingLobbyId, i);

        // Skip ourselves
        if (memberId == mySteamId) {
            continue;
        }

        // Get the player's difficulty
        const char* difficultyStr = SteamMatchmaking()->GetLobbyMemberData(
            m_matchmakingLobbyId, memberId, "difficulty");

        if (!difficultyStr) {
            continue; // Skip players without difficulty set
        }

        int memberDifficulty = atoi(difficultyStr);

        // Check if difficulty matches
        if (memberDifficulty == m_selectedMatchmakingDifficulty) {
            STEAM_DEBUG("Found match with player:" << memberId.ConvertToUint64()
            << "for difficulty:" << m_selectedMatchmakingDifficulty);

            // Create a game lobby
            createGameLobbyWithMatch(memberId);
            return; // Exit after finding one match
        }
    }
}

void SteamIntegration::createGameLobbyWithMatch(CSteamID matchedPlayerId) {
    // Stop matchmaking timer
    m_matchmakingTimer.stop();

    // Create a new private game lobby
    SteamAPICall_t apiCall = SteamMatchmaking()->CreateLobby(k_ELobbyTypePrivate, 2);

    // Store the matched player ID for later
    m_pendingMatchedPlayerId = matchedPlayerId;

    // Use lobbyCreatedCallback with a different handler
    m_lobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnGameLobbyCreated);

    // Flag that we're setting up a match
    m_isSettingUpMatch = true;

    STEAM_DEBUG("Creating game lobby for matched player:" << matchedPlayerId.ConvertToUint64());
}

void SteamIntegration::OnGameLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure) {
    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        STEAM_DEBUG("Failed to create game lobby for matchmaking");

        // Return to matchmaking
        m_isSettingUpMatch = false;
        if (m_inMatchmaking) {
            m_matchmakingTimer.start();
        }

        return;
    }

    CSteamID gameLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    STEAM_DEBUG("Created game lobby with ID:" << gameLobbyId.ConvertToUint64());

    // Set lobby data
    SteamMatchmaking()->SetLobbyData(gameLobbyId, "game", "Retr0Mine");
    SteamMatchmaking()->SetLobbyData(gameLobbyId, "version", "1.0");
    SteamMatchmaking()->SetLobbyData(gameLobbyId, "matchmade", "1");

    // Set difficulty data
    char difficultyStr[2];
    snprintf(difficultyStr, sizeof(difficultyStr), "%d", m_selectedMatchmakingDifficulty);
    SteamMatchmaking()->SetLobbyData(gameLobbyId, "difficulty", difficultyStr);

    // Instead of inviting, set the game lobby ID in the matchmaking lobby
    // so the matched player can auto-join
    if (m_matchmakingLobbyId.IsValid()) {
        char gameLobbyIdStr[64];
        snprintf(gameLobbyIdStr, sizeof(gameLobbyIdStr), "%llu", gameLobbyId.ConvertToUint64());
        SteamMatchmaking()->SetLobbyData(m_matchmakingLobbyId, "game_lobby_id", gameLobbyIdStr);

        // Set target player ID so only the right player joins
        char targetPlayerIdStr[64];
        snprintf(targetPlayerIdStr, sizeof(targetPlayerIdStr), "%llu", m_pendingMatchedPlayerId.ConvertToUint64());
        SteamMatchmaking()->SetLobbyData(m_matchmakingLobbyId, "target_player_id", targetPlayerIdStr);
    }

    // Update state
    m_inMatchmaking = false;
    m_isSettingUpMatch = false;
    m_currentLobbyId = gameLobbyId;
    m_isHost = true;
    m_inMultiplayerGame = true;

    // Emit signals
    emit matchmakingStatusChanged();
    emit hostStatusChanged();
    emit multiplayerStatusChanged();

    QString matchedPlayerName = SteamFriends()->GetFriendPersonaName(m_pendingMatchedPlayerId);
    emit matchFound(matchedPlayerName);

    // Start the network timer
    m_networkTimer.start();

    // Clear pending matched player
    m_pendingMatchedPlayerId = CSteamID();

    // Leave matchmaking lobby after a delay to ensure data propagates
    QTimer::singleShot(1000, [this]() {
        if (m_matchmakingLobbyId.IsValid()) {
            SteamMatchmaking()->LeaveLobby(m_matchmakingLobbyId);
            m_matchmakingLobbyId = CSteamID();
        }
    });
}

void SteamIntegration::setSelectedMatchmakingDifficulty(int difficulty) {
    if (m_selectedMatchmakingDifficulty != difficulty) {
        m_selectedMatchmakingDifficulty = difficulty;

        // If we're in matchmaking, update our metadata
        if (m_inMatchmaking && m_matchmakingLobbyId.IsValid()) {
            char difficultyStr[2];
            snprintf(difficultyStr, sizeof(difficultyStr), "%d", m_selectedMatchmakingDifficulty);
            SteamMatchmaking()->SetLobbyMemberData(m_matchmakingLobbyId, "difficulty", difficultyStr);

            // Refresh queue counts
            refreshQueueCounts();
        }

        emit selectedDifficultyChanged();
    }
}

int SteamIntegration::getAvatarHandleForPlayerName(const QString& playerName) {
    if (!m_initialized)
        return 0;

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return 0;

    // Get local player name to check if the requested avatar is for the local player
    CSteamID localUserID = SteamUser()->GetSteamID();
    QString localPlayerName = QString::fromUtf8(steamFriends->GetPersonaName());

    // If the requested name matches the local player, return their avatar
    if (playerName == localPlayerName) {
        return steamFriends->GetMediumFriendAvatar(localUserID);
    }

    // Otherwise, search through friends as before
    int friendCount = steamFriends->GetFriendCount(k_EFriendFlagImmediate);
    for (int i = 0; i < friendCount; i++) {
        CSteamID friendId = steamFriends->GetFriendByIndex(i, k_EFriendFlagImmediate);
        QString friendName = QString::fromUtf8(steamFriends->GetFriendPersonaName(friendId));

        if (friendName == playerName) {
            return steamFriends->GetMediumFriendAvatar(friendId);
        }
    }

    return 0;
}

void SteamIntegration::OnLobbyInvite(LobbyInvite_t *pCallback)
{
    CSteamID friendID = pCallback->m_ulSteamIDUser;
    CSteamID lobbyID = pCallback->m_ulSteamIDLobby;

    QString friendName = QString::fromUtf8(SteamFriends()->GetFriendPersonaName(friendID));
    QString lobbyIdStr = QString::number(lobbyID.ConvertToUint64());

    STEAM_DEBUG("Invite from:" << friendName << "to lobby:" << lobbyIdStr);

    // Emit signal for QML
    emit inviteReceived(friendName, lobbyIdStr);
}

void SteamIntegration::checkForPendingInvites()
{
    if (!m_initialized || m_inMultiplayerGame) {
        STEAM_DEBUG("SteamIntegration: Cannot check for pending invites - not initialized or already in game");
        return;
    }

    // Check command line arguments for +connect_lobby parameter
    QStringList args = QCoreApplication::arguments();
    QString lobbyIdStr;
    for (int i = 0; i < args.size(); i++) {
        QString arg = args[i];
        if (arg.startsWith("+connect_lobby")) {
            // Handle both "+connect_lobby 12345" and "+connect_lobby=12345" formats
            if (arg == "+connect_lobby" && i + 1 < args.size()) {
                lobbyIdStr = args[i + 1];
            } else if (arg.startsWith("+connect_lobby=")) {
                lobbyIdStr = arg.mid(15); // Extract ID after '='
            }
            break;
        }
    }

    if (!lobbyIdStr.isEmpty()) {
        bool ok;
        uint64 lobbyId = lobbyIdStr.toULongLong(&ok);
        if (ok && lobbyId != 0) {
            acceptInvite(QString::number(lobbyId));
            return;
        }
    }

    // Check for any lobby the user has recently been invited to
    if (SteamUtils()) {
        CSteamID lobbyId = SteamMatchmaking()->GetLobbyByIndex(0);
        if (lobbyId.IsValid()) {
            // Verify this is a recent invite to our game
            const char* gameIdStr = SteamMatchmaking()->GetLobbyData(lobbyId, "game");
            if (gameIdStr && QString(gameIdStr) == "Retr0Mine") {
                STEAM_DEBUG("SteamIntegration: Found pending Retr0Mine lobby invite:" << lobbyId.ConvertToUint64();
                acceptInvite(QString::number(lobbyId.ConvertToUint64())));
                return;
            }
        }
    }

    SteamAPI_RunCallbacks();
}

void SteamIntegration::handlePingPongMessage(const QByteArray& messageData, const CSteamID& senderId)
{
    // Ping messages can be very short
    if (messageData.startsWith("PING")) {
        // Respond with PONG
        QByteArray response;
        response.append('P');
        response.append("PONG");
        SteamNetworking()->SendP2PPacket(
            senderId,
            response.constData(),
            response.size(),
            k_EP2PSendReliable
            );
    } else if (messageData.startsWith("PONG")) {
        // Calculate ping time if we sent a ping
        if (m_lastPingSent > 0) {
            int now = QDateTime::currentMSecsSinceEpoch();
            m_pingTime = now - m_lastPingSent;
            m_lastPingSent = 0;

            // If ping is too high, emit a warning signal
            if (m_pingTime > 500 && m_p2pInitialized && m_connectionState == Connected) {
                updateConnectionState(Unstable);
                emit connectionUnstable();
            }

            emit pingTimeChanged(m_pingTime);
        }
    }
}

void SteamIntegration::measurePing()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || !m_p2pInitialized) {
        return;
    }

    STEAM_DEBUG("SteamIntegration: Explicitly measuring ping");

    // Use system message for reliable ping measurement
    QVariantMap pingData;
    pingData["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    sendSystemMessage("ping_test", pingData);

    // Log the ping request
    m_lastPingSent = QDateTime::currentMSecsSinceEpoch();
}
