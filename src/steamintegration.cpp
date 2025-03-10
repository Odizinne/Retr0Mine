#include "steamintegration.h"
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
#include <steam_api.h>

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
    , m_inMultiplayerGame(false)
    , m_isHost(false)
    , m_isConnecting(false)
    , m_lobbyReady(false)
    , m_p2pInitialized(false)
    , m_connectionCheckFailCount(0)
{
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();

    connect(&m_p2pInitTimer, &QTimer::timeout, this, &SteamIntegration::sendP2PInitPing);
    connect(&m_networkTimer, &QTimer::timeout, this, &SteamIntegration::processNetworkMessages);
    connect(&m_connectionHealthTimer, &QTimer::timeout, this, &SteamIntegration::checkConnectionHealth);
    QTimer* callbackTimer = new QTimer(this);
    connect(callbackTimer, &QTimer::timeout, this, &SteamIntegration::runCallbacks);
    callbackTimer->start(100);

    m_networkTimer.setInterval(50);
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
        m_networkTimer.stop();
        m_p2pInitTimer.stop();

        ISteamNetworking* steamNet = SteamNetworking();
        if (steamNet) {
            P2PSessionState_t sessionState;
            bool hasSession = steamNet->GetP2PSessionState(m_connectedPlayerId, &sessionState);

            if (m_connectedPlayerId.IsValid()) {
                steamNet->CloseP2PSessionWithUser(m_connectedPlayerId);
            }

            SteamAPI_RunCallbacks();
        }

        if (m_currentLobbyId.IsValid()) {
            SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
            SteamAPI_RunCallbacks();
        }

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
    m_networkTimer.stop();
    m_p2pInitTimer.stop();
    m_connectionHealthTimer.stop();

    if (m_initialized && m_connectedPlayerId.IsValid()) {
        qDebug() << "SteamIntegration: Closing P2P session with:" << m_connectedPlayerId.ConvertToUint64();
        SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
        SteamAPI_RunCallbacks();
    }

    if (m_initialized && m_inMultiplayerGame && m_currentLobbyId.IsValid()) {
        qDebug() << "SteamIntegration: Leaving lobby:" << m_currentLobbyId.ConvertToUint64();
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
        SteamAPI_RunCallbacks();
    }

    m_inMultiplayerGame = false;
    m_isHost = false;
    m_lobbyReady = false;
    m_p2pInitialized = false;
    m_isConnecting = false;
    m_currentLobbyId = CSteamID();
    m_connectedPlayerId = CSteamID();
    m_connectedPlayerName = "";

    if (m_initialized && !isShuttingDown) {
        updateRichPresence();
        SteamAPI_RunCallbacks();
    }

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
        qDebug() << "Rich Presence update failed: Could not get SteamFriends interface";
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

void SteamIntegration::createLobby()
{
    qDebug() << "SteamIntegration: Creating lobby...";
    if (!m_initialized) {
        qDebug() << "SteamIntegration: Cannot create lobby - Steam not initialized";
        return;
    }

    if (m_inMultiplayerGame) {
        qDebug() << "SteamIntegration: Cannot create lobby - Already in multiplayer game";
        return;
    }

    // We're creating a lobby for 2 players (host + 1 friend)
    SteamAPICall_t apiCall = SteamMatchmaking()->CreateLobby(k_ELobbyTypePrivate, 2);

    if (apiCall == k_uAPICallInvalid) {
        qDebug() << "SteamIntegration: CreateLobby API call failed";
        emit connectionFailed("Failed to create Steam API call");
        return;
    }

    // Register the callback for this specific API call
    m_lobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnLobbyCreated);

    m_isConnecting = true;
    emit connectingStatusChanged();
}

void SteamIntegration::OnLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure)
{
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        qDebug() << "SteamIntegration: Lobby creation failed with error:"
                 << (bIOFailure ? "I/O Failure" : QString::number(pCallback->m_eResult));
        emit connectionFailed("Failed to create lobby (error " +
                              QString(bIOFailure ? "I/O Failure" : QString::number(pCallback->m_eResult)) + ")");
        return;
    }

    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    qDebug() << "SteamIntegration: Lobby created with ID:" << m_currentLobbyId.ConvertToUint64();

    m_isHost = true;
    m_inMultiplayerGame = true;

    emit hostStatusChanged();
    emit multiplayerStatusChanged();
    emit canInviteFriendChanged();

    // Set lobby data (game name, version, etc.)
    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "game", "Retr0Mine");
    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "version", "1.0");

    updateRichPresence();

    m_networkTimer.start();

    emit connectionSucceeded();
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
    qDebug() << "SteamIntegration: Inviting friend:" << friendId;
    if (!m_initialized || !m_inMultiplayerGame || !m_isHost) {
        qDebug() << "SteamIntegration: Cannot invite - not initialized, not in game, or not host";
        return;
    }

    CSteamID steamFriendId(friendId.toULongLong());
    if (steamFriendId.IsValid() && m_currentLobbyId.IsValid()) {
        SteamMatchmaking()->InviteUserToLobby(m_currentLobbyId, steamFriendId);
        qDebug() << "SteamIntegration: Invitation sent to:" << friendId;
    }
}

void SteamIntegration::acceptInvite(const QString& lobbyId)
{
    qDebug() << "SteamIntegration: Accepting invite to lobby:" << lobbyId;
    if (!m_initialized || m_inMultiplayerGame) {
        qDebug() << "SteamIntegration: Cannot accept invite - not initialized or already in game";
        return;
    }

    CSteamID steamLobbyId(lobbyId.toULongLong());
    if (steamLobbyId.IsValid()) {
        m_isConnecting = true;
        emit connectingStatusChanged();

        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(steamLobbyId);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);
        qDebug() << "SteamIntegration: Join lobby call made, waiting for callback";
    }
}

void SteamIntegration::leaveLobby()
{
    qDebug() << "SteamIntegration: Leaving lobby";
    if (!m_initialized)
        return;

    // Even if we think we're not in a multiplayer game, try to clean up
    // This helps with edge cases where the state got out of sync

    // If we have a valid lobby ID, try to leave it directly first
    if (m_currentLobbyId.IsValid()) {
        qDebug() << "SteamIntegration: Leaving lobby ID:" << m_currentLobbyId.ConvertToUint64();
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
    }

    // Then do thorough cleanup
    cleanupMultiplayerSession();
}

void SteamIntegration::OnLobbyEntered(LobbyEnter_t *pCallback, bool bIOFailure) {
    qDebug() << "SteamIntegration: OnLobbyEntered callback received";

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

        qDebug() << "SteamIntegration: Failed to enter lobby, error:" << errorMessage;
        emit connectionFailed(errorMessage);
        return;
    }

    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);

    // Check what type of lobby this is
    const char* lobbyType = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "lobby_type");
    const char* matchmade = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "matchmade");

    if (lobbyType && strcmp(lobbyType, "matchmaking") == 0) {
        // This is a matchmaking lobby
        qDebug() << "SteamIntegration: Joined matchmaking lobby";

        m_matchmakingLobbyId = m_currentLobbyId;
        m_inMatchmaking = true;
        m_inMultiplayerGame = false;

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
        qDebug() << "SteamIntegration: Joined matchmade game lobby";

        m_inMatchmaking = false;
        m_inMultiplayerGame = true;

        // Determine if we're the host
        CSteamID lobbyOwner = SteamMatchmaking()->GetLobbyOwner(m_currentLobbyId);
        m_isHost = (lobbyOwner == SteamUser()->GetSteamID());

        qDebug() << "SteamIntegration: Matchmade game lobby, host status:" << m_isHost;

        // If we're not the host, the lobby owner is our connected player
        if (!m_isHost) {
            m_connectedPlayerId = lobbyOwner;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(lobbyOwner);
            emit connectedPlayerChanged();

            startP2PInitialization();
        }

        // Start the network timer
        m_networkTimer.start();

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
        // This is a regular game lobby (existing code)
        qDebug() << "SteamIntegration: Joined regular game lobby";

        m_inMultiplayerGame = true;

        // Determine if we're the host
        CSteamID lobbyOwner = SteamMatchmaking()->GetLobbyOwner(m_currentLobbyId);
        m_isHost = (lobbyOwner == SteamUser()->GetSteamID());

        qDebug() << "SteamIntegration: Joined lobby, host status:" << m_isHost;

        // If we're not the host, the lobby owner is our connected player
        if (!m_isHost) {
            m_connectedPlayerId = lobbyOwner;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(lobbyOwner);
            emit connectedPlayerChanged();

            startP2PInitialization();
        }

        m_networkTimer.start();

        emit multiplayerStatusChanged();
        emit hostStatusChanged();
        emit canInviteFriendChanged();
        emit connectionSucceeded();
    }

    qDebug() << "SteamIntegration: Lobby join complete";
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
                qDebug() << "Auto-joining game lobby:" << gameLobbyId.ConvertToUint64();

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
                qDebug() << "SteamIntegration: Lobby marked as ready";
            }
        }
    }
}

void SteamIntegration::OnLobbyChatUpdate(LobbyChatUpdate_t *pCallback) {
    // Handle player join/leave events
    qDebug() << "SteamIntegration: Lobby chat update received";

    // Check if this update is for one of our lobbies
    bool isCurrentLobby = (pCallback->m_ulSteamIDLobby == m_currentLobbyId.ConvertToUint64());
    bool isMatchmakingLobby = (pCallback->m_ulSteamIDLobby == m_matchmakingLobbyId.ConvertToUint64());

    if (!isCurrentLobby && !isMatchmakingLobby) {
        return; // Not for any of our lobbies
    }

    qDebug() << "SteamIntegration: Lobby chat update for "
             << (isMatchmakingLobby ? "matchmaking" : "game")
             << " lobby, change flags:" << pCallback->m_rgfChatMemberStateChange;

    // Check the chat member change flags
    if (pCallback->m_rgfChatMemberStateChange & k_EChatMemberStateChangeEntered) {
        // A player joined the lobby
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (isMatchmakingLobby) {
            // For matchmaking lobby, just update queue counts
            qDebug() << "SteamIntegration: Player" << playerId.ConvertToUint64()
                     << "joined matchmaking lobby, updating queue counts";
            refreshQueueCounts();

        } else if (m_isHost && playerId != SteamUser()->GetSteamID()) {
            // If we're the host and someone else joined our game lobby, that's our connected player
            qDebug() << "SteamIntegration: Player joined our hosted game lobby";

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

            qDebug() << "SteamIntegration: Player joined lobby:" << m_connectedPlayerName;
        }
    }
    else if (pCallback->m_rgfChatMemberStateChange & (k_EChatMemberStateChangeLeft | k_EChatMemberStateChangeDisconnected)) {
        // A player left the lobby
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (isMatchmakingLobby) {
            // For matchmaking lobby, just update queue counts
            qDebug() << "SteamIntegration: Player" << playerId.ConvertToUint64()
                     << "left matchmaking lobby, updating queue counts";
            refreshQueueCounts();

        } else if (playerId == m_connectedPlayerId) {
            // Our connected player left the game lobby
            qDebug() << "SteamIntegration: Connected player left game lobby";

            m_connectedPlayerId = CSteamID();
            m_connectedPlayerName = "";
            m_lobbyReady = false;

            emit connectedPlayerChanged();
            emit lobbyReadyChanged();

            qDebug() << "SteamIntegration: Connected player left lobby";

            // You might want to end the multiplayer session
            leaveLobby();
        }
    }
}

void SteamIntegration::OnP2PSessionRequest(P2PSessionRequest_t *pCallback)
{
    // Accept P2P connections from lobby members
    CSteamID requestorId = pCallback->m_steamIDRemote;
    qDebug() << "SteamIntegration: P2P session request from:" << requestorId.ConvertToUint64();

    // Only accept connections from players in our lobby
    int memberCount = SteamMatchmaking()->GetNumLobbyMembers(m_currentLobbyId);
    for (int i = 0; i < memberCount; i++) {
        CSteamID memberId = SteamMatchmaking()->GetLobbyMemberByIndex(m_currentLobbyId, i);
        if (memberId == requestorId) {
            SteamNetworking()->AcceptP2PSessionWithUser(requestorId);
            qDebug() << "SteamIntegration: P2P session accepted";
            return;
        }
    }

    qDebug() << "SteamIntegration: P2P session rejected - user not in lobby";
}

void SteamIntegration::OnP2PSessionConnectFail(P2PSessionConnectFail_t *pCallback)
{
    // Handle connection failures
    CSteamID failedId = pCallback->m_steamIDRemote;
    qDebug() << "SteamIntegration: P2P session connect failed with:" << failedId.ConvertToUint64();

    if (failedId == m_connectedPlayerId) {
        QString errorReason;
        errorReason = "Connection failed (error " + QString::number(pCallback->m_eP2PSessionError) + ")";

        qDebug() << "SteamIntegration: Connection failed with connected player:" << errorReason;
        emit connectionFailed(errorReason);
        leaveLobby();
    }
}

void SteamIntegration::OnGameLobbyJoinRequested(GameLobbyJoinRequested_t *pCallback)
{
    // This callback is triggered when the player accepts a lobby invite from the Steam overlay
    uint64 lobbyID = pCallback->m_steamIDLobby.ConvertToUint64();
    qDebug() << "SteamIntegration: Game lobby join requested for lobby:" << lobbyID;

    if (m_inMultiplayerGame) {
        // Already in a game, need to leave first
        qDebug() << "SteamIntegration: Already in a game, leaving first";
        leaveLobby();

        // Give a little time for cleanup before joining
        QTimer::singleShot(500, [this, lobbyID]() {
            // Join the requested lobby after cleanup
            m_isConnecting = true;
            emit connectingStatusChanged();

            SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(CSteamID(lobbyID));
            m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

            qDebug() << "SteamIntegration: Join requested lobby call made after leaving previous game";
        });
    } else {
        // Join the requested lobby immediately
        m_isConnecting = true;
        emit connectingStatusChanged();

        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(pCallback->m_steamIDLobby);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

        qDebug() << "SteamIntegration: Join requested lobby call made, waiting for callback";
    }
}

void SteamIntegration::processNetworkMessages()
{
    if (!m_initialized || !m_inMultiplayerGame)
        return;

    uint32 msgSize;
    while (SteamNetworking()->IsP2PPacketAvailable(&msgSize)) {
        if (msgSize > 8192) {
            qDebug() << "SteamIntegration: Skipping oversized packet:" << msgSize;
            continue; // Skip oversized packets
        }

        QByteArray buffer(msgSize, 0);
        CSteamID senderId;

        if (SteamNetworking()->ReadP2PPacket(buffer.data(), msgSize, &msgSize, &senderId)) {
            // Process the message based on a simple header
            if (msgSize < 2) {
                qDebug() << "SteamIntegration: Skipping too small packet:" << msgSize;
                continue; // Need at least message type
            }

            char messageType = buffer[0];
            QByteArray messageData = buffer.mid(1);

            //qDebug() << "SteamIntegration: Received message type:" << messageType
            //         << "size:" << messageData.size() << "from:" << senderId.ConvertToUint64();

            // Mark P2P as initialized on first message from either side
            if (!m_p2pInitialized) {
                qDebug() << "SteamIntegration: P2P connection fully established!";
                m_p2pInitialized = true;
                emit p2pInitialized();
                updateRichPresence();

                // Stop the ping timer if it's running
                m_p2pInitTimer.stop();
            }

            switch (messageType) {
            case 'P':
                if (messageData == "PING") {
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
                }
                // If we received a PONG, we don't need to do anything special
                // The connection is already marked as initialized above
                break;
            case 'A': // Action (reveal/flag)
                handleGameAction(messageData);
                break;
            case 'S': // State update
                handleGameState(messageData);
                break;
            // Add other message types as needed
            default:
                qDebug() << "SteamIntegration: Unknown message type:" << messageType;
                break;
            }
        }
    }
}

bool SteamIntegration::sendGameAction(const QString& actionType, const QVariant& parameter)
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        qDebug() << "SteamIntegration: Cannot send game action - not initialized, not in game, or no connected player";
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
        qDebug() << "SteamIntegration: Sending string action:" << actionType
                 << "with text:" << stringParameter << "to:" << m_connectedPlayerId.ConvertToUint64();
    } else {
        // Original behavior for number parameters
        // Format: A|actionType|cellIndex
        int cellIndex = parameter.toInt();
        data.append(actionType.toUtf8());
        data.append('|');
        data.append(QByteArray::number(cellIndex));
        qDebug() << "SteamIntegration: Sending game action:" << actionType
                 << "for cell:" << cellIndex << "to:" << m_connectedPlayerId.ConvertToUint64();
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
        qDebug() << "SteamIntegration: Cannot send game state - not initialized, not in game, or no connected player";
        return false;
    }

    // Serialize the game state to JSON
    QJsonDocument doc = QJsonDocument::fromVariant(gameState);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    // Prepare packet: S + JSON data
    QByteArray packet;
    packet.append('S');
    packet.append(jsonData);

    qDebug() << "SteamIntegration: Sending game state, size:" << jsonData.size()
             << "to:" << m_connectedPlayerId.ConvertToUint64();

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
        qDebug() << "SteamIntegration: Invalid game action format";
        return;
    }

    QString actionType = QString::fromUtf8(data.left(separatorPos));
    QByteArray parameterData = data.mid(separatorPos + 1);

    // Try to convert to integer first
    bool isInt = false;
    int cellIndex = parameterData.toInt(&isInt);

    if (isInt) {
        // Handle numeric parameter
        qDebug() << "SteamIntegration: Received game action:" << actionType << "for cell:" << cellIndex;
        emit gameActionReceived(actionType, cellIndex);
    } else {
        // Handle string parameter (for chat messages)
        QString stringParam = QString::fromUtf8(parameterData);
        qDebug() << "SteamIntegration: Received string action:" << actionType << "with text:" << stringParam;
        emit gameActionReceived(actionType, stringParam);
    }
}

void SteamIntegration::handleGameState(const QByteArray& data)
{
    // Parse JSON game state
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull() || !doc.isObject()) {
        qDebug() << "SteamIntegration: Invalid game state JSON";
        return;
    }

    QVariantMap gameState = doc.object().toVariantMap();
    qDebug() << "SteamIntegration: Received game state with keys:" << gameState.keys();
    emit gameStateReceived(gameState);
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

void SteamIntegration::startP2PInitialization() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        return;
    }

    qDebug() << "SteamIntegration: Starting P2P initialization process";
    m_p2pInitialized = false;

    m_p2pInitTimer.setInterval(500);
    m_p2pInitTimer.start();

    m_connectionHealthTimer.setInterval(5000);
    m_connectionHealthTimer.start();

    sendP2PInitPing();
}

void SteamIntegration::checkForPendingInvites()
{
    if (!m_initialized || m_inMultiplayerGame) {
        qDebug() << "SteamIntegration: Cannot check for pending invites - Steam not initialized";
        return;
    }

    // METHOD 1: Check command line arguments for +connect_lobby parameter
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

    // METHOD 2: Check if we have a valid lobby from SteamGameCoordinator
    if (SteamUtils()) {
        // Check for pending invites through the Steam API
        uint32 appID = SteamUtils()->GetAppID();

        // METHOD 3: Check for any lobby the user has recently been invited to
        // GetLobbyByIndex returns a CSteamID directly, not a bool with output parameter
        CSteamID lobbyId = SteamMatchmaking()->GetLobbyByIndex(0);
        if (lobbyId.IsValid()) {

            // Verify this is a recent invite to our game
            const char* gameIdStr = SteamMatchmaking()->GetLobbyData(lobbyId, "game");
            if (gameIdStr && QString(gameIdStr) == "Retr0Mine") {
                qDebug() << "SteamIntegration: Found pending Retr0Mine lobby invite:" << lobbyId.ConvertToUint64();
                acceptInvite(QString::number(lobbyId.ConvertToUint64()));
                return;
            }
        }
    }

    SteamAPI_RunCallbacks();
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

    qDebug() << "Invite from:" << friendName << "to lobby:" << lobbyIdStr;

    // Emit signal for QML
    emit inviteReceived(friendName, lobbyIdStr);
}

void SteamIntegration::checkConnectionHealth() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        // No need to check if we're not in a multiplayer game
        m_connectionHealthTimer.stop();
        return;
    }

    // Check P2P session state
    P2PSessionState_t sessionState;
    bool hasSession = SteamNetworking()->GetP2PSessionState(m_connectedPlayerId, &sessionState);

    if (!hasSession || sessionState.m_bConnectionActive == 0) {
        m_connectionCheckFailCount++;
        qDebug() << "SteamIntegration: Connection check failed" << m_connectionCheckFailCount << "times";

        if (m_connectionCheckFailCount >= MAX_CONNECTION_FAILURES) {
            qDebug() << "SteamIntegration: Connection lost to player, cleaning up multiplayer session";

            // Emit a signal to notify about the disconnection
            //emit connectionFailed("Connection to player lost");

            emit notifyConnectionLost(m_connectedPlayerName);

            // Clean up just the multiplayer session without affecting the game state
            cleanupMultiplayerSession();
            m_connectionCheckFailCount = 0;

        }
    } else {
        // Reset failure counter if check is successful
        if (m_connectionCheckFailCount > 0) {
            qDebug() << "SteamIntegration: Connection healthy again";
            m_connectionCheckFailCount = 0;
        }
    }
}

void SteamIntegration::enterMatchmaking(int difficulty) {
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

    qDebug() << "Found" << lobbyCount << "matchmaking lobbies";

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
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnMatchmakingLobbyEntered);
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
    qDebug() << "Created matchmaking lobby with ID:" << m_matchmakingLobbyId.ConvertToUint64();

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

void SteamIntegration::OnMatchmakingLobbyEntered(LobbyEnter_t* pCallback, bool bIOFailure) {
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_EChatRoomEnterResponse != k_EChatRoomEnterResponseSuccess) {
        QString errorMessage;

        if (bIOFailure) {
            errorMessage = "I/O Failure";
        } else {
            switch (pCallback->m_EChatRoomEnterResponse) {
            case k_EChatRoomEnterResponseDoesntExist:
                errorMessage = "Matchmaking lobby no longer exists";
                break;
            case k_EChatRoomEnterResponseNotAllowed:
            case k_EChatRoomEnterResponseBanned:
            case k_EChatRoomEnterResponseLimited:
                errorMessage = "You don't have permission to join this matchmaking lobby";
                break;
            case k_EChatRoomEnterResponseFull:
                errorMessage = "Matchmaking lobby is already full";
                break;
            case k_EChatRoomEnterResponseError:
            default:
                errorMessage = "Unknown error joining matchmaking (" +
                               QString::number(pCallback->m_EChatRoomEnterResponse) + ")";
                break;
            }
        }

        qDebug() << "SteamIntegration: Failed to enter matchmaking lobby, error:" << errorMessage;
        emit matchmakingError(errorMessage);
        return;
    }

    // Set matchmaking lobby ID
    m_matchmakingLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    qDebug() << "SteamIntegration: Joined matchmaking lobby with ID:" << m_matchmakingLobbyId.ConvertToUint64();

    // Set player metadata for matchmaking
    char difficultyStr[2];
    snprintf(difficultyStr, sizeof(difficultyStr), "%d", m_selectedMatchmakingDifficulty);
    SteamMatchmaking()->SetLobbyMemberData(m_matchmakingLobbyId, "difficulty", difficultyStr);

    // Update state
    m_inMatchmaking = true;
    emit matchmakingStatusChanged();

    // Start checking for matches
    m_matchmakingTimer.setInterval(2000); // Check every 2 seconds
    m_matchmakingTimer.setSingleShot(false);
    m_matchmakingTimer.start();
    connect(&m_matchmakingTimer, &QTimer::timeout, this, &SteamIntegration::checkForMatches);

    // Update queue counts
    refreshQueueCounts();

    qDebug() << "SteamIntegration: Successfully joined matchmaking system";
}

void SteamIntegration::checkForMatches() {
    if (!m_initialized || !m_inMatchmaking || !m_matchmakingLobbyId.IsValid()) {
        m_matchmakingTimer.stop();
        return;
    }

    // Update queue counts first
    refreshQueueCounts();

    // Check if there's a game lobby we should join
    const char* gameLobbyIdStr = SteamMatchmaking()->GetLobbyData(m_matchmakingLobbyId, "game_lobby_id");
    const char* targetPlayerIdStr = SteamMatchmaking()->GetLobbyData(m_matchmakingLobbyId, "target_player_id");

    if (gameLobbyIdStr && targetPlayerIdStr && strlen(gameLobbyIdStr) > 0) {
        CSteamID targetPlayerId(strtoull(targetPlayerIdStr, nullptr, 10));

        // Check if we're the targeted player
        if (targetPlayerId == SteamUser()->GetSteamID()) {
            CSteamID gameLobbyId(strtoull(gameLobbyIdStr, nullptr, 10));
            qDebug() << "Found game lobby to join:" << gameLobbyId.ConvertToUint64();

            // Stop matchmaking and join the game
            m_matchmakingTimer.stop();
            m_inMatchmaking = false;
            emit matchmakingStatusChanged();

            m_isConnecting = true;
            emit connectingStatusChanged();

            SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(gameLobbyId);
            m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

            // Leave the matchmaking lobby
            SteamMatchmaking()->LeaveLobby(m_matchmakingLobbyId);
            m_matchmakingLobbyId = CSteamID();

            return; // Don't continue with regular matching
        }
    }

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
            qDebug() << "Found match with player:" << memberId.ConvertToUint64()
            << "for difficulty:" << m_selectedMatchmakingDifficulty;

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

    qDebug() << "Creating game lobby for matched player:" << matchedPlayerId.ConvertToUint64();
}

void SteamIntegration::OnGameLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure) {
    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        qDebug() << "Failed to create game lobby for matchmaking";

        // Return to matchmaking
        m_isSettingUpMatch = false;
        if (m_inMatchmaking) {
            m_matchmakingTimer.start();
        }

        return;
    }

    CSteamID gameLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    qDebug() << "Created game lobby with ID:" << gameLobbyId.ConvertToUint64();

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

    qDebug() << "Left matchmaking";
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
