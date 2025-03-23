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
    , m_reconnectionAttempts(0) {
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();

    connect(&m_p2pInitTimer, &QTimer::timeout, this, &SteamIntegration::sendP2PInitPing);
    connect(&m_networkTimer, &QTimer::timeout, this, &SteamIntegration::processNetworkMessages);
    connect(&m_connectionHealthTimer, &QTimer::timeout, this, &SteamIntegration::checkConnectionHealth);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &SteamIntegration::sendHeartbeat);
    connect(&m_reconnectionTimer, &QTimer::timeout, this, &SteamIntegration::tryReconnect);

    QTimer* callbackTimer = new QTimer(this);
    connect(callbackTimer, &QTimer::timeout, this, &SteamIntegration::runCallbacks);
    callbackTimer->start(100);

    m_networkTimer.setInterval(50);
    m_heartbeatTimer.setInterval(HEARTBEAT_INTERVAL);
    m_connectionHealthTimer.setInterval(5000);
    m_reconnectionTimer.setInterval(3000);
}

SteamIntegration::~SteamIntegration() {
    if (m_initialized) {
        if (m_inMultiplayerGame || m_connectedPlayerId.IsValid()) {
            cleanupMultiplayerSession(true);
        }
        shutdown();
    }
}

bool SteamIntegration::initialize() {
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

void SteamIntegration::shutdown() {
    if (m_initialized) {
        m_networkTimer.stop();
        m_p2pInitTimer.stop();
        m_heartbeatTimer.stop();
        m_connectionHealthTimer.stop();
        m_reconnectionTimer.stop();

        ISteamNetworking* steamNet = SteamNetworking();
        if (steamNet && m_connectedPlayerId.IsValid()) {
            steamNet->CloseP2PSessionWithUser(m_connectedPlayerId);
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

void SteamIntegration::cleanupMultiplayerSession(bool isShuttingDown) {
    m_networkTimer.stop();
    m_p2pInitTimer.stop();
    m_heartbeatTimer.stop();
    m_connectionHealthTimer.stop();
    m_reconnectionTimer.stop();

    if (m_initialized && m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("Closing P2P session with:" << m_connectedPlayerId.ConvertToUint64());
        SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
        SteamAPI_RunCallbacks();
    }

    if (m_initialized && m_inMultiplayerGame && m_currentLobbyId.IsValid()) {
        STEAM_DEBUG("Leaving lobby:" << m_currentLobbyId.ConvertToUint64());
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
        SteamAPI_RunCallbacks();
    }

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

    updateConnectionState(Disconnected);

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

void SteamIntegration::unlockAchievement(const QString &achievementId) {
    if (!m_initialized)
        return;
    ISteamUserStats *steamUserStats = SteamUserStats();
    if (!steamUserStats)
        return;
    steamUserStats->SetAchievement(achievementId.toUtf8().constData());
    steamUserStats->StoreStats();
}

bool SteamIntegration::isAchievementUnlocked(const QString &achievementId) const {
    if (!m_initialized)
        return false;
    ISteamUserStats *steamUserStats = SteamUserStats();
    if (!steamUserStats)
        return false;
    bool achieved = false;
    steamUserStats->GetAchievement(achievementId.toUtf8().constData(), &achieved);
    return achieved;
}

bool SteamIntegration::isRunningOnDeck() const {
    if (!m_initialized)
        return false;
    ISteamUtils *steamUtils = SteamUtils();
    if (!steamUtils)
        return false;
    return steamUtils->IsSteamRunningOnSteamDeck();
}

QString SteamIntegration::getSteamUILanguage() const {
    if (!m_initialized)
        return QString();

    ISteamUtils* steamUtils = SteamUtils();
    if (!steamUtils)
        return QString();

    const char* language = steamUtils->GetSteamUILanguage();
    return QString::fromUtf8(language);
}

void SteamIntegration::updatePlayerName() {
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

bool SteamIntegration::incrementTotalWin() {
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

void SteamIntegration::setDifficulty(int difficulty) {
    if (m_p2pInitialized) return;
    if (m_difficulty != difficulty) {
        m_difficulty = difficulty;
        updateRichPresence();
    }
}

QString SteamIntegration::getDifficultyString() const {
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

void SteamIntegration::updateRichPresence() {
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

void SteamIntegration::runCallbacks() {
    if (m_initialized) {
        SteamAPI_RunCallbacks();
    }
}

void SteamIntegration::updateConnectionState(ConnectionState newState) {
    if (m_connectionState != newState) {
        ConnectionState oldState = m_connectionState;
        m_connectionState = newState;

        STEAM_DEBUG("Connection state changed from" << oldState << "to" << newState);

        if (newState == Connected) {
            m_missedHeartbeats = 0;
            m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();

            if (!m_heartbeatTimer.isActive()) {
                m_heartbeatTimer.start();
            }

            measurePing();
        }
        else if (newState == Disconnected) {
            m_heartbeatTimer.stop();

            m_pingTime = 0;
            emit pingTimeChanged(m_pingTime);
        }

        emit connectionStateChanged(newState);
    }
}

void SteamIntegration::createLobby() {
    STEAM_DEBUG("Creating lobby...");
    if (!m_initialized) {
        STEAM_DEBUG("Cannot create lobby - Steam not initialized");
        emit connectionFailed("Steam not initialized");
        return;
    }

    if (m_inMultiplayerGame) {
        STEAM_DEBUG("Cannot create lobby - Already in multiplayer game");
        emit connectionFailed("Already in multiplayer game");
        return;
    }

    SteamAPICall_t apiCall = SteamMatchmaking()->CreateLobby(k_ELobbyTypePrivate, 2);

    if (apiCall == k_uAPICallInvalid) {
        STEAM_DEBUG("CreateLobby API call failed");
        emit connectionFailed("Failed to create Steam API call");
        return;
    }

    m_lobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnLobbyCreated);

    m_isConnecting = true;
    updateConnectionState(Connecting);
    emit connectingStatusChanged();
}

void SteamIntegration::OnLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure) {
    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_eResult != k_EResultOK) {
        QString errorMessage = bIOFailure ?
                                   "I/O Failure" :
                                   QString("Error %1").arg(pCallback->m_eResult);

        STEAM_DEBUG("Lobby creation failed with error:" << errorMessage);
        updateConnectionState(Disconnected);
        emit connectionFailed("Failed to create lobby (" + errorMessage + ")");
        return;
    }

    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    STEAM_DEBUG("Lobby created with ID:" << m_currentLobbyId.ConvertToUint64());

    m_isHost = true;
    m_inMultiplayerGame = true;

    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "game", "Retr0Mine");
    SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "version", "1.0");

    m_networkTimer.start();

    updateConnectionState(Connected);

    emit hostStatusChanged();
    emit multiplayerStatusChanged();
    emit canInviteFriendChanged();
    emit connectionSucceeded();

    updateRichPresence();
}

QStringList SteamIntegration::getOnlineFriends() {
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

QString SteamIntegration::getAvatarImageForHandle(int handle) {
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

    QImage image(reinterpret_cast<const uchar*>(imageData.data()), width, height, QImage::Format_RGBA8888);

    QImage resizedImage = image.scaled(24, 24, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    QSettings settings("Odizinne", "Retr0Mine");
    bool shouldRound = (settings.value("themeIndex").toInt() == 0);

    QImage result;

    if (shouldRound) {
        QImage rounded(24, 24, QImage::Format_ARGB32_Premultiplied);
        rounded.fill(Qt::transparent);

        QPainter painter(&rounded);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

        int x = (24 - resizedImage.width()) / 2;
        int y = (24 - resizedImage.height()) / 2;

        QPainterPath path;
        path.addRoundedRect(0, 0, 24, 24, 4, 4);
        painter.setClipPath(path);
        painter.drawImage(x, y, resizedImage);
        painter.end();

        result = rounded;
    } else {
        if (resizedImage.width() != 24 || resizedImage.height() != 24) {
            QImage centered(24, 24, QImage::Format_ARGB32_Premultiplied);
            centered.fill(Qt::transparent);

            QPainter painter(&centered);

            int x = (24 - resizedImage.width()) / 2;
            int y = (24 - resizedImage.height()) / 2;

            painter.drawImage(x, y, resizedImage);
            painter.end();

            result = centered;
        } else {
            result = resizedImage;
        }
    }

    QByteArray pngData;
    QBuffer buffer(&pngData);
    buffer.open(QIODevice::WriteOnly);
    result.save(&buffer, "PNG");
    buffer.close();

    return QString("data:image/png;base64,") + pngData.toBase64();
}

void SteamIntegration::inviteFriend(const QString& friendId) {
    STEAM_DEBUG("Inviting friend:" << friendId);
    if (!m_initialized || !m_inMultiplayerGame || !m_isHost) {
        STEAM_DEBUG("Cannot invite - not initialized, not in game, or not host");
        return;
    }

    CSteamID steamFriendId(friendId.toULongLong());
    if (steamFriendId.IsValid() && m_currentLobbyId.IsValid()) {
        SteamMatchmaking()->InviteUserToLobby(m_currentLobbyId, steamFriendId);
        STEAM_DEBUG("Invitation sent to:" << friendId);
    }
}

void SteamIntegration::acceptInvite(const QString& lobbyId) {
    STEAM_DEBUG("Accepting invite to lobby:" << lobbyId);
    if (!m_initialized) {
        STEAM_DEBUG("Cannot accept invite - Steam not initialized");
        emit connectionFailed("Steam not initialized");
        return;
    }

    if (m_inMultiplayerGame) {
        STEAM_DEBUG("Cannot accept invite - Already in a game");
        emit connectionFailed("Already in a multiplayer game");
        return;
    }

    CSteamID steamLobbyId(lobbyId.toULongLong());
    if (steamLobbyId.IsValid()) {
        m_isConnecting = true;
        updateConnectionState(Connecting);
        emit connectingStatusChanged();

        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(steamLobbyId);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);
        STEAM_DEBUG("Join lobby call made, waiting for callback");
    } else {
        STEAM_DEBUG("Invalid lobby ID:" << lobbyId);
        emit connectionFailed("Invalid lobby ID");
    }
}

void SteamIntegration::leaveLobby() {
    STEAM_DEBUG("Leaving lobby");
    if (!m_initialized)
        return;

    if (m_p2pInitialized && m_connectedPlayerId.IsValid()) {
        sendSystemMessage("disconnect", {{"reason", "User left the game"}});
    }

    if (m_currentLobbyId.IsValid()) {
        STEAM_DEBUG("Leaving lobby ID:" << m_currentLobbyId.ConvertToUint64());
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
    }

    cleanupMultiplayerSession();
}

void SteamIntegration::OnLobbyEntered(LobbyEnter_t *pCallback, bool bIOFailure) {
    STEAM_DEBUG("OnLobbyEntered callback received");

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

        STEAM_DEBUG("Failed to enter lobby, error:" << errorMessage);
        updateConnectionState(Disconnected);
        emit connectionFailed(errorMessage);
        return;
    }

    m_currentLobbyId = CSteamID(pCallback->m_ulSteamIDLobby);
    STEAM_DEBUG("Joined regular game lobby");

    m_inMultiplayerGame = true;

    CSteamID lobbyOwner = SteamMatchmaking()->GetLobbyOwner(m_currentLobbyId);
    m_isHost = (lobbyOwner == SteamUser()->GetSteamID());

    STEAM_DEBUG("Joined lobby, host status:" << m_isHost);

    if (!m_isHost) {
        m_connectedPlayerId = lobbyOwner;
        m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(lobbyOwner);
        emit connectedPlayerChanged();

        startP2PInitialization();
    }

    m_networkTimer.start();

    updateConnectionState(Connected);

    emit multiplayerStatusChanged();
    emit hostStatusChanged();
    emit canInviteFriendChanged();
    emit connectionSucceeded();

    updateRichPresence();

    STEAM_DEBUG("Lobby join complete");
}

void SteamIntegration::OnLobbyDataUpdate(LobbyDataUpdate_t *pCallback) {
    if (m_currentLobbyId.IsValid() && m_currentLobbyId.ConvertToUint64() == pCallback->m_ulSteamIDLobby) {
        const char* gameReadyValue = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "game_ready");
        if (gameReadyValue && QString(gameReadyValue) == "1") {
            if (!m_lobbyReady) {
                m_lobbyReady = true;
                emit lobbyReadyChanged();
                STEAM_DEBUG("Lobby marked as ready");
            }
        }
    }
}

void SteamIntegration::OnLobbyChatUpdate(LobbyChatUpdate_t *pCallback) {
    STEAM_DEBUG("Lobby chat update received");

    bool isCurrentLobby = (pCallback->m_ulSteamIDLobby == m_currentLobbyId.ConvertToUint64());

    if (!isCurrentLobby) {
        return;
    }

    STEAM_DEBUG("Lobby chat update for game lobby, change flags:" << pCallback->m_rgfChatMemberStateChange);

    if (pCallback->m_rgfChatMemberStateChange & k_EChatMemberStateChangeEntered) {
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (m_isHost && playerId != SteamUser()->GetSteamID()) {
            STEAM_DEBUG("Player joined our hosted game lobby");

            m_connectedPlayerId = playerId;
            m_connectedPlayerName = SteamFriends()->GetFriendPersonaName(playerId);
            emit connectedPlayerChanged();

            if (!m_lobbyReady) {
                SteamMatchmaking()->SetLobbyData(m_currentLobbyId, "game_ready", "1");
                m_lobbyReady = true;
                emit lobbyReadyChanged();
            }

            startP2PInitialization();

            STEAM_DEBUG("Player joined lobby:" << m_connectedPlayerName);
        }
    }
    else if (pCallback->m_rgfChatMemberStateChange & (k_EChatMemberStateChangeLeft | k_EChatMemberStateChangeDisconnected)) {
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);

        if (playerId == m_connectedPlayerId) {
            STEAM_DEBUG("Connected player left game lobby");

            QString playerName = m_connectedPlayerName;

            updateConnectionState(Disconnected);

            cleanupMultiplayerSession();

            emit notifyConnectionLost(playerName);
        }
    }
}

void SteamIntegration::OnP2PSessionRequest(P2PSessionRequest_t *pCallback) {
    CSteamID requestorId = pCallback->m_steamIDRemote;
    STEAM_DEBUG("P2P session request from:" << requestorId.ConvertToUint64());

    if (m_currentLobbyId.IsValid()) {
        int memberCount = SteamMatchmaking()->GetNumLobbyMembers(m_currentLobbyId);
        for (int i = 0; i < memberCount; i++) {
            CSteamID memberId = SteamMatchmaking()->GetLobbyMemberByIndex(m_currentLobbyId, i);
            if (memberId == requestorId) {
                SteamNetworking()->AcceptP2PSessionWithUser(requestorId);
                STEAM_DEBUG("P2P session accepted");

                if (m_attemptingReconnection && requestorId == m_connectedPlayerId) {
                    STEAM_DEBUG("Reconnection request accepted");
                }

                return;
            }
        }
    }

    if (m_attemptingReconnection && requestorId == m_connectedPlayerId) {
        SteamNetworking()->AcceptP2PSessionWithUser(requestorId);
        STEAM_DEBUG("Reconnection P2P session accepted");
        return;
    }

    STEAM_DEBUG("P2P session rejected - user not in lobby");
}

void SteamIntegration::OnP2PSessionConnectFail(P2PSessionConnectFail_t *pCallback) {
    CSteamID failedId = pCallback->m_steamIDRemote;
    STEAM_DEBUG("P2P session connect failed with:" << failedId.ConvertToUint64());

    if (failedId == m_connectedPlayerId) {
        QString errorReason = "Connection failed (error " + QString::number(pCallback->m_eP2PSessionError) + ")";
        STEAM_DEBUG("Connection failed with connected player:" << errorReason);

        if (m_attemptingReconnection) {
            m_reconnectionAttempts++;

            if (m_reconnectionAttempts >= MAX_RECONNECTION_ATTEMPTS) {
                STEAM_DEBUG("Maximum reconnection attempts reached");
                updateConnectionState(Disconnected);
                m_attemptingReconnection = false;
                emit reconnectionFailed();
                cleanupMultiplayerSession();
                emit notifyConnectionLost(m_connectedPlayerName);
            } else {
                STEAM_DEBUG("Reconnection attempt" << m_reconnectionAttempts << "failed, retrying...");
            }
        } else {
            updateConnectionState(Disconnected);
            emit connectionFailed(errorReason);
            cleanupMultiplayerSession();
        }
    }
}

void SteamIntegration::OnGameLobbyJoinRequested(GameLobbyJoinRequested_t *pCallback) {
    uint64 lobbyID = pCallback->m_steamIDLobby.ConvertToUint64();
    STEAM_DEBUG("Game lobby join requested for lobby:" << lobbyID);

    if (m_inMultiplayerGame) {
        STEAM_DEBUG("Already in a game, leaving first");
        leaveLobby();

        QTimer::singleShot(500, [this, lobbyID]() {
            m_isConnecting = true;
            updateConnectionState(Connecting);
            emit connectingStatusChanged();

            SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(CSteamID(lobbyID));
            m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

            STEAM_DEBUG("Join requested lobby call made after leaving previous game");
        });
    } else {
        m_isConnecting = true;
        updateConnectionState(Connecting);
        emit connectingStatusChanged();

        SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(pCallback->m_steamIDLobby);
        m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

        STEAM_DEBUG("Join requested lobby call made, waiting for callback");
    }
}

void SteamIntegration::processNetworkMessages() {
    if (!m_initialized || (!m_inMultiplayerGame && !m_attemptingReconnection))
        return;

    uint32 msgSize;
    while (SteamNetworking()->IsP2PPacketAvailable(&msgSize)) {
        if (msgSize > 16384) {
            STEAM_DEBUG("Skipping oversized packet:" << msgSize);

            QByteArray discardBuffer(msgSize, 0);
            CSteamID senderId;
            SteamNetworking()->ReadP2PPacket(discardBuffer.data(), msgSize, nullptr, &senderId);
            continue;
        }

        QByteArray buffer(msgSize, 0);
        CSteamID senderId;

        if (SteamNetworking()->ReadP2PPacket(buffer.data(), msgSize, &msgSize, &senderId)) {
            if (msgSize < 1) {
                STEAM_DEBUG("Empty packet received, skipping");
                continue;
            }

            m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();

            char messageType = buffer[0];
            QByteArray messageData;

            if (msgSize > 1) {
                messageData = buffer.mid(1);
            }

            if (!m_p2pInitialized) {
                STEAM_DEBUG("P2P connection established on message receipt!");
                m_p2pInitialized = true;
                updateConnectionState(Connected);
                emit p2pInitialized();

                if (m_attemptingReconnection) {
                    m_attemptingReconnection = false;
                    m_reconnectionAttempts = 0;
                    m_reconnectionTimer.stop();
                    emit reconnectionSucceeded();
                }

                m_missedHeartbeats = 0;
                m_heartbeatTimer.start();
                m_connectionHealthTimer.start();

                updateRichPresence();
            }

            m_missedHeartbeats = 0;

            if (m_connectionState == Unstable) {
                updateConnectionState(Connected);
            }

            switch (messageType) {
            case 'P':
                if (messageData.startsWith("PING")) {
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
                    if (m_lastPingSent > 0) {
                        int now = QDateTime::currentMSecsSinceEpoch();
                        m_pingTime = now - m_lastPingSent;
                        m_lastPingSent = 0;

                        if (m_pingTime > 500 && m_p2pInitialized && m_connectionState == Connected) {
                            updateConnectionState(Unstable);
                            emit connectionUnstable();
                        }

                        emit pingTimeChanged(m_pingTime);
                    }
                }
                break;

            case 'H':
                break;

            case 'S':
                if (messageData.size() > 0) {
                    bool success = handleSystemMessage(messageData);
                    if (!success) {
                        STEAM_DEBUG("Error handling system message");
                    }
                }
                break;

            case 'A':
                if (messageData.size() > 0) {
                    bool success = handleGameAction(messageData);
                    if (!success) {
                        STEAM_DEBUG("Error handling game action");
                    }
                }
                break;

            case 'D':
                if (messageData.size() > 0) {
                    bool success = handleGameState(messageData);
                    if (!success) {
                        STEAM_DEBUG("Error handling game state");
                    }
                }
                break;

            default:
                STEAM_DEBUG("Unknown message type:" << messageType << "size:" << messageData.size());
                break;
            }
        } else {
            STEAM_DEBUG("Failed to read P2P packet");
        }
    }

    static int messageLoopCounter = 0;
    messageLoopCounter++;

    if (messageLoopCounter >= 10) {
        messageLoopCounter = 0;

        if (m_p2pInitialized && m_connectionState != Connected && m_connectionState != Unstable) {
            STEAM_DEBUG("Fixing inconsistent connection state: p2pInitialized but state is" << m_connectionState);
            updateConnectionState(Connected);
        }
    }
}

bool SteamIntegration::sendGameAction(const QString& actionType, const QVariant& parameter) {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("Cannot send game action - not initialized, not in game, or no connected player");
        return false;
    }

    if (m_connectionState != Connected && m_connectionState != Unstable) {
        STEAM_DEBUG("Cannot send game action - connection not established");
        return false;
    }

    QByteArray data;
    data.append('A');

    if (parameter.typeId() == QMetaType::QString) {
        QString stringParameter = parameter.toString();
        data.append(actionType.toUtf8());
        data.append('|');
        data.append(stringParameter.toUtf8());

        STEAM_DEBUG("Sending string action:" << actionType
                                             << "with text:" << stringParameter.left(20) + (stringParameter.length() > 20 ? "..." : "")
                                             << "to:" << m_connectedPlayerId.ConvertToUint64());
    } else {
        int cellIndex = parameter.toInt();
        data.append(actionType.toUtf8());
        data.append('|');
        data.append(QByteArray::number(cellIndex));

        STEAM_DEBUG("Sending game action:" << actionType
                                           << "for cell:" << cellIndex << "to:" << m_connectedPlayerId.ConvertToUint64());
    }

    return SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}

bool SteamIntegration::sendGameState(const QVariantMap& gameState) {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("Cannot send game state - not initialized, not in game, or no connected player");
        return false;
    }

    if (m_connectionState != Connected && m_connectionState != Unstable) {
        STEAM_DEBUG("Cannot send game state - connection not established");
        return false;
    }

    QJsonDocument doc = QJsonDocument::fromVariant(gameState);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    QByteArray packet;
    packet.append('D');
    packet.append(jsonData);

    QString logData = jsonData.size() > 100 ?
                          QString(jsonData.left(100)) + "... (total size: " + QString::number(jsonData.size()) + ")" :
                          QString(jsonData);

    STEAM_DEBUG("Sending game state:" << logData
                                      << "to:" << m_connectedPlayerId.ConvertToUint64());

    return SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        packet.constData(),
        packet.size(),
        k_EP2PSendReliable
        );
}

bool SteamIntegration::handleGameAction(const QByteArray& data) {
    int separatorPos = data.indexOf('|');
    if (separatorPos == -1) {
        STEAM_DEBUG("Invalid game action format");
        return false;
    }

    QString actionType = QString::fromUtf8(data.left(separatorPos));
    QByteArray parameterData = data.mid(separatorPos + 1);

    bool isInt = false;
    int cellIndex = parameterData.toInt(&isInt);

    if (isInt) {
        STEAM_DEBUG("Received game action:" << actionType << "for cell:" << cellIndex);
        emit gameActionReceived(actionType, cellIndex);
    } else {
        QString stringParam = QString::fromUtf8(parameterData);
        STEAM_DEBUG("Received string action:" << actionType
                                              << "with text:" << stringParam.left(20) + (stringParam.length() > 20 ? "..." : ""));
        emit gameActionReceived(actionType, stringParam);
    }

    return true;
}

bool SteamIntegration::handleGameState(const QByteArray& data) {
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        STEAM_DEBUG("Invalid game state JSON:" << parseError.errorString());
        STEAM_DEBUG("Data snippet:" << data.left(100));
        return false;
    }

    if (!doc.isObject()) {
        STEAM_DEBUG("Game state is not a JSON object");
        return false;
    }

    QVariantMap gameState = doc.object().toVariantMap();

    QStringList keys = gameState.keys();
    STEAM_DEBUG("Received game state with keys:" << keys);

    emit gameStateReceived(gameState);

    return true;
}

bool SteamIntegration::handleSystemMessage(const QByteArray& data) {
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        STEAM_DEBUG("Invalid system message JSON:" << parseError.errorString());
        return false;
    }
    if (!doc.isObject()) {
        STEAM_DEBUG("System message is not a JSON object");
        return false;
    }
    QVariantMap message = doc.object().toVariantMap();
    QString type = message["type"].toString();
    STEAM_DEBUG("Received system message type:" << type);
    if (type == "disconnect") {
        QString reason = message["reason"].toString();
        STEAM_DEBUG("Received disconnect message, reason:" << reason);
        updateConnectionState(Disconnected);
        cleanupMultiplayerSession();
        emit notifyConnectionLost(m_connectedPlayerName);
    }
    else if (type == "reconnect_request") {
        STEAM_DEBUG("Received reconnection request");
        sendSystemMessage("reconnect_ack");
        updateConnectionState(Reconnecting);
    }
    else if (type == "reconnect_ack") {
        STEAM_DEBUG("Reconnection request acknowledged");
        m_heartbeatTimer.start();
        m_connectionHealthTimer.start();
        updateConnectionState(Connected);
        m_attemptingReconnection = false;
        m_reconnectionAttempts = 0;
        m_reconnectionTimer.stop();
        emit reconnectionSucceeded();
    }
    else if (type == "ping_test") {
        QVariant timestamp = message["timestamp"];
        STEAM_DEBUG("Received ping test, echoing timestamp:" << timestamp.toLongLong());
        QVariantMap responseData;
        responseData["timestamp"] = timestamp;
        sendSystemMessage("ping_response", responseData);
    }
    else if (type == "ping_response") {
        QVariant timestamp = message["timestamp"];
        if (timestamp.isValid()) {
            bool ok;
            qint64 sentTime = timestamp.toLongLong(&ok);
            if (ok) {
                qint64 now = QDateTime::currentMSecsSinceEpoch();
                m_pingTime = now - sentTime;
                STEAM_DEBUG("Ping time calculated:" << m_pingTime << "ms");
                emit pingTimeChanged(m_pingTime);
                if (m_pingTime > 500 && m_connectionState == Connected) {
                    updateConnectionState(Unstable);
                    emit connectionUnstable();
                }
            }
        }
    }
    return true;
}

void SteamIntegration::sendSystemMessage(const QString& type, const QVariantMap& data) {
    if (!m_initialized || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("Cannot send system message - not initialized or no connected player");
        return;
    }

    QVariantMap message = data;
    message["type"] = type;

    QJsonDocument doc = QJsonDocument::fromVariant(message);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    QByteArray packet;
    packet.append('S');
    packet.append(jsonData);

    STEAM_DEBUG("Sending system message type:" << type
                                               << "to:" << m_connectedPlayerId.ConvertToUint64());

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        packet.constData(),
        packet.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::sendP2PInitPing() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        m_p2pInitTimer.stop();
        return;
    }

    QByteArray data;
    data.append('P');
    data.append("PING");

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::sendHeartbeat() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        m_heartbeatTimer.stop();
        return;
    }

    char heartbeat = 'H';

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        &heartbeat,
        1,
        k_EP2PSendUnreliable
        );

    static int heartbeatCounter = 0;
    heartbeatCounter = (heartbeatCounter + 1) % 5;

    if (heartbeatCounter == 0 && m_p2pInitialized) {
        measurePing();
    }
}

bool SteamIntegration::forcePing() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || !m_p2pInitialized) {
        return false;
    }

    m_lastPingSent = QDateTime::currentMSecsSinceEpoch();

    QByteArray data;
    data.append('P');
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
        m_connectionHealthTimer.stop();
        return;
    }

    P2PSessionState_t sessionState;
    bool hasSession = SteamNetworking()->GetP2PSessionState(m_connectedPlayerId, &sessionState);

    if (!hasSession || sessionState.m_bConnectionActive == 0) {
        m_connectionCheckFailCount++;
        STEAM_DEBUG("Steam session check failed" << m_connectionCheckFailCount << "times");

        if (m_connectionCheckFailCount >= MAX_CONNECTION_FAILURES) {
            STEAM_DEBUG("Connection lost according to Steam, attempting reconnection");
            if (m_connectionState == Connected) {
                updateConnectionState(Unstable);
                emit connectionUnstable();
            } else if (m_connectionState == Unstable) {
                requestReconnection();
            }
        }
        return;
    }

    m_connectionCheckFailCount = 0;

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    qint64 timeSinceLastMessage = now - m_lastMessageTime;

    if (m_p2pInitialized && timeSinceLastMessage > 15000) {
        STEAM_DEBUG("No messages received for" << timeSinceLastMessage << "ms");

        m_missedHeartbeats++;
        STEAM_DEBUG("Heartbeat timeout:" << m_missedHeartbeats);

        if (m_missedHeartbeats >= MAX_MISSED_HEARTBEATS) {
            if (m_connectionState == Connected) {
                STEAM_DEBUG("Too many missed heartbeats, connection unstable");
                updateConnectionState(Unstable);
                emit connectionUnstable();

                forcePing();
            } else if (m_connectionState == Unstable && timeSinceLastMessage > 30000) {
                STEAM_DEBUG("Connection stalled, attempting reconnection");
                requestReconnection();
            }
        }
    } else {
        if (m_missedHeartbeats > 0) {
            m_missedHeartbeats = 0;

            if (m_connectionState == Unstable) {
                STEAM_DEBUG("Connection recovered");
                updateConnectionState(Connected);
            }
        }
    }
}

void SteamIntegration::resetConnectionHealth() {
    m_connectionCheckFailCount = 0;
    m_missedHeartbeats = 0;
    m_lastMessageTime = QDateTime::currentMSecsSinceEpoch();
}

void SteamIntegration::requestReconnection() {
    if (!m_initialized || !m_connectedPlayerId.IsValid()) {
        STEAM_DEBUG("Cannot request reconnection - not initialized or no connected player");
        return;
    }

    if (m_connectionState == Disconnected) {
        STEAM_DEBUG("Already disconnected, cannot reconnect");
        return;
    }

    if (m_attemptingReconnection) {
        STEAM_DEBUG("Reconnection already in progress");
        return;
    }

    STEAM_DEBUG("Initiating reconnection process");

    updateConnectionState(Reconnecting);

    m_attemptingReconnection = true;
    m_reconnectionAttempts = 0;

    tryReconnect();

    m_reconnectionTimer.start();
}

void SteamIntegration::tryReconnect() {
    if (!m_initialized || !m_connectedPlayerId.IsValid() || !m_attemptingReconnection) {
        m_reconnectionTimer.stop();
        return;
    }

    m_reconnectionAttempts++;
    STEAM_DEBUG("Reconnection attempt" << m_reconnectionAttempts);

    if (m_reconnectionAttempts > MAX_RECONNECTION_ATTEMPTS) {
        STEAM_DEBUG("Maximum reconnection attempts reached");
        m_attemptingReconnection = false;
        m_reconnectionTimer.stop();
        updateConnectionState(Disconnected);
        emit reconnectionFailed();

        cleanupMultiplayerSession();
        emit notifyConnectionLost(m_connectedPlayerName);
        return;
    }

    sendSystemMessage("reconnect_request");

    SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
    SteamAPI_RunCallbacks();

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

    STEAM_DEBUG("Starting P2P initialization process");

    m_p2pInitialized = false;
    updateConnectionState(Connecting);
    m_missedHeartbeats = 0;

    m_p2pInitTimer.setInterval(500);
    m_p2pInitTimer.start();

    m_connectionHealthTimer.setInterval(5000);
    m_connectionHealthTimer.start();

    sendP2PInitPing();
}

bool SteamIntegration::testConnection() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        return false;
    }

    P2PSessionState_t sessionState;
    bool hasSession = SteamNetworking()->GetP2PSessionState(m_connectedPlayerId, &sessionState);

    if (!hasSession || sessionState.m_bConnectionActive == 0) {
        STEAM_DEBUG("Connection test failed - no active session");
        return false;
    }

    return forcePing();
}

void SteamIntegration::OnLobbyInvite(LobbyInvite_t *pCallback) {
    CSteamID friendID = pCallback->m_ulSteamIDUser;
    CSteamID lobbyID = pCallback->m_ulSteamIDLobby;

    QString friendName = QString::fromUtf8(SteamFriends()->GetFriendPersonaName(friendID));
    QString lobbyIdStr = QString::number(lobbyID.ConvertToUint64());

    STEAM_DEBUG("Invite from:" << friendName << "to lobby:" << lobbyIdStr);

    emit inviteReceived(friendName, lobbyIdStr);
}

void SteamIntegration::checkForPendingInvites() {
    if (!m_initialized || m_inMultiplayerGame) {
        STEAM_DEBUG("Cannot check for pending invites - not initialized or already in game");
        return;
    }

    QStringList args = QCoreApplication::arguments();
    QString lobbyIdStr;
    for (int i = 0; i < args.size(); i++) {
        QString arg = args[i];
        if (arg.startsWith("+connect_lobby")) {
            if (arg == "+connect_lobby" && i + 1 < args.size()) {
                lobbyIdStr = args[i + 1];
            } else if (arg.startsWith("+connect_lobby=")) {
                lobbyIdStr = arg.mid(15);
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

    if (SteamUtils()) {
        CSteamID lobbyId = SteamMatchmaking()->GetLobbyByIndex(0);
        if (lobbyId.IsValid()) {
            const char* gameIdStr = SteamMatchmaking()->GetLobbyData(lobbyId, "game");
            if (gameIdStr && QString(gameIdStr) == "Retr0Mine") {
                STEAM_DEBUG("Found pending Retr0Mine lobby invite:" << lobbyId.ConvertToUint64());
                acceptInvite(QString::number(lobbyId.ConvertToUint64()));
                return;
            }
        }
    }

    SteamAPI_RunCallbacks();
}

void SteamIntegration::handlePingPongMessage(const QByteArray& messageData, const CSteamID& senderId) {
    if (messageData.startsWith("PING")) {
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
        if (m_lastPingSent > 0) {
            int now = QDateTime::currentMSecsSinceEpoch();
            m_pingTime = now - m_lastPingSent;
            m_lastPingSent = 0;

            if (m_pingTime > 500 && m_p2pInitialized && m_connectionState == Connected) {
                updateConnectionState(Unstable);
                emit connectionUnstable();
            }

            emit pingTimeChanged(m_pingTime);
        }
    }
}

void SteamIntegration::measurePing() {
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || !m_p2pInitialized) {
        return;
    }

    STEAM_DEBUG("Explicitly measuring ping");

    QVariantMap pingData;
    pingData["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    sendSystemMessage("ping_test", pingData);

    m_lastPingSent = QDateTime::currentMSecsSinceEpoch();
}

int SteamIntegration::getAvatarHandleForPlayerName(const QString& playerName) {
    if (!m_initialized)
        return 0;

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return 0;

    CSteamID localUserID = SteamUser()->GetSteamID();
    QString localPlayerName = QString::fromUtf8(steamFriends->GetPersonaName());

    if (playerName == localPlayerName) {
        return steamFriends->GetMediumFriendAvatar(localUserID);
    }

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
