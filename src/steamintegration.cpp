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

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
    , m_inMultiplayerGame(false)
    , m_isHost(false)
    , m_isConnecting(false)
    , m_lobbyReady(false)
    , m_p2pInitialized(false)
    , m_currentPing(-1)
{
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();

    // Setup periodic network message checking
    connect(&m_p2pInitTimer, &QTimer::timeout, this, &SteamIntegration::sendP2PInitPing);
    connect(&m_networkTimer, &QTimer::timeout, this, &SteamIntegration::processNetworkMessages);
    connect(&m_pingTimer, &QTimer::timeout, this, &SteamIntegration::sendPingRequest);

    // Create a Steam callback timer to ensure callbacks are processed regularly
    QTimer* callbackTimer = new QTimer(this);
    connect(callbackTimer, &QTimer::timeout, this, &SteamIntegration::runCallbacks);
    callbackTimer->start(100);

    m_networkTimer.setInterval(50);
}

SteamIntegration::~SteamIntegration()
{
    // First, ensure all multiplayer sessions are cleaned up
    cleanupMultiplayerSession(true);

    if (m_initialized) {
        // Close any P2P sessions explicitly again to be sure
        ISteamNetworking* steamNetworking = SteamNetworking();
        if (steamNetworking) {
            // Get all Steam friends and ensure P2P sessions are closed with each
            ISteamFriends* steamFriends = SteamFriends();
            if (steamFriends) {
                int friendCount = steamFriends->GetFriendCount(k_EFriendFlagImmediate);
                for (int i = 0; i < friendCount; i++) {
                    CSteamID friendId = steamFriends->GetFriendByIndex(i, k_EFriendFlagImmediate);
                    steamNetworking->CloseP2PSessionWithUser(friendId);
                }
            }

            // Flush and process all remaining packets
            uint32 msgSize;
            while (steamNetworking->IsP2PPacketAvailable(&msgSize)) {
                QByteArray buffer(msgSize, 0);
                CSteamID senderId;
                steamNetworking->ReadP2PPacket(buffer.data(), msgSize, &msgSize, &senderId);
            }
        }

        // Run Steam callbacks to process the close requests
        // Increased iterations with dynamic checking
        const int MAX_ITERATIONS = 30;
        for (int i = 0; i < MAX_ITERATIONS; i++) {
            SteamAPI_RunCallbacks();
            QThread::msleep(20);

            // Check if there are any pending packets - if not for a few iterations, we can break early
            if (steamNetworking && !steamNetworking->IsP2PPacketAvailable(nullptr)) {
                // If we've had a few clean iterations, we can break
                if (i > 10) break;
            }
        }

        // Clear rich presence before shutdown
        ISteamFriends* steamFriends = SteamFriends();
        if (steamFriends) {
            steamFriends->ClearRichPresence();
        }
    }

    // Finally shut down the Steam API
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
    updatePlayerName();
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

        // Stop network message processing
        m_networkTimer.stop();

        SteamAPI_Shutdown();
        m_initialized = false;
    }
}

void SteamIntegration::cleanupMultiplayerSession(bool isShuttingDown)
{
    qDebug() << "SteamIntegration: Cleaning up multiplayer session, shutdown:" << isShuttingDown;

    // First stop all timers to prevent callbacks during cleanup
    m_networkTimer.stop();
    m_p2pInitTimer.stop();

    // Close any open P2P sessions
    if (m_initialized) {
        ISteamNetworking* steamNetworking = SteamNetworking();
        if (steamNetworking && m_connectedPlayerId.IsValid()) {
            qDebug() << "SteamIntegration: Closing P2P session with:" << m_connectedPlayerId.ConvertToUint64();
            steamNetworking->CloseP2PSessionWithUser(m_connectedPlayerId);

            // Add a delay and process callbacks to allow the session to close properly
            if (isShuttingDown) {
                // Process callbacks a few times to allow session closure to complete
                for (int i = 0; i < 5; i++) {
                    SteamAPI_RunCallbacks();
                    QThread::msleep(10); // Short delay
                }
            }
        }

        // Process any remaining packets
        uint32 msgSize;
        int maxPackets = 50;
        int packetCount = 0;

        while (steamNetworking && steamNetworking->IsP2PPacketAvailable(&msgSize) && packetCount < maxPackets) {
            // Read and discard any pending packets
            QByteArray buffer(msgSize, 0);
            CSteamID senderId;
            steamNetworking->ReadP2PPacket(buffer.data(), msgSize, &msgSize, &senderId);
            packetCount++;
        }
    }

    // Leave the lobby if we're in one
    if (m_initialized && m_inMultiplayerGame && m_currentLobbyId.IsValid()) {
        qDebug() << "SteamIntegration: Leaving lobby:" << m_currentLobbyId.ConvertToUint64();
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);

        // Allow time for the lobby leave operation to complete
        if (isShuttingDown) {
            for (int i = 0; i < 3; i++) {
                SteamAPI_RunCallbacks();
                QThread::msleep(10);
            }
        }
    }

    // Reset multiplayer state variables
    m_inMultiplayerGame = false;
    m_isHost = false;
    m_lobbyReady = false;
    m_p2pInitialized = false;
    m_isConnecting = false;
    m_currentLobbyId = CSteamID();
    m_connectedPlayerId = CSteamID();
    m_connectedPlayerName = "";
    m_pingTimer.stop();
    m_pendingPings.clear();
    m_currentPing = -1;

    // Run callbacks one final time
    if (isShuttingDown && m_initialized) {
        SteamAPI_RunCallbacks();
    }

    // Update rich presence if not shutting down
    if (m_initialized && !isShuttingDown) {
        updateRichPresence();
    }

    // Emit signals if not shutting down
    if (!isShuttingDown) {
        emit multiplayerStatusChanged();
        emit hostStatusChanged();
        emit lobbyReadyChanged();
        emit connectedPlayerChanged();
        emit canInviteFriendChanged();
        emit p2pInitialized();
    }

    qDebug() << "SteamIntegration: Multiplayer session cleaned up";
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

    if (m_inMultiplayerGame) {
        // Set multiplayer-specific rich presence
        steamFriends->SetRichPresence("status", m_isHost ? "Hosting" : "Playing with friend");
        steamFriends->SetRichPresence("steam_display", "#PlayingMultiplayer");
    } else {
        // Regular rich presence
        steamFriends->SetRichPresence("difficulty", getDifficultyString().toUtf8().constData());
        steamFriends->SetRichPresence("steam_display", "#PlayingDifficulty");
    }
}

// Run Steam callbacks - call this regularly from main loop
void SteamIntegration::runCallbacks()
{
    if (m_initialized) {
        SteamAPI_RunCallbacks();
    }
}

//-------------------------------------------------------------------------
// NEW MULTIPLAYER METHODS
//-------------------------------------------------------------------------

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

    // Update rich presence to show we're hosting
    updateRichPresence();

    // Start listening for P2P connections
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

            // Get avatar image handle
            int avatarHandle = steamFriends->GetSmallFriendAvatar(friendId);

            // Format: "FriendName:SteamID:AvatarHandle"
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

    // Convert to PNG and then to base64
    QByteArray pngData;
    QBuffer buffer(&pngData);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "PNG");
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

void SteamIntegration::OnLobbyEntered(LobbyEnter_t *pCallback, bool bIOFailure)
{
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

        // Start P2P initialization
        startP2PInitialization();
    }

    // Start P2P networking
    m_networkTimer.start();

    emit multiplayerStatusChanged();
    emit hostStatusChanged();
    emit canInviteFriendChanged();
    emit connectionSucceeded();

    // Update rich presence to show multiplayer status
    updateRichPresence();

    qDebug() << "SteamIntegration: Lobby join complete";
}

void SteamIntegration::OnLobbyDataUpdate(LobbyDataUpdate_t *pCallback)
{
    // Check if this is our lobby
    if (m_currentLobbyId.ConvertToUint64() != pCallback->m_ulSteamIDLobby)
        return;

    // Example: Check if the game is ready to start
    const char* gameReadyValue = SteamMatchmaking()->GetLobbyData(m_currentLobbyId, "game_ready");
    if (gameReadyValue && QString(gameReadyValue) == "1") {
        if (!m_lobbyReady) {
            m_lobbyReady = true;
            emit lobbyReadyChanged();
            qDebug() << "SteamIntegration: Lobby marked as ready";
        }
    }
}

void SteamIntegration::OnLobbyChatUpdate(LobbyChatUpdate_t *pCallback)
{
    // Handle player join/leave events
    qDebug() << "SteamIntegration: Lobby chat update received";

    if (pCallback->m_ulSteamIDLobby != m_currentLobbyId.ConvertToUint64())
        return;

    qDebug() << "SteamIntegration: Lobby chat update for our lobby, change flags:"
             << pCallback->m_rgfChatMemberStateChange;

    // Check the chat member change flags
    if (pCallback->m_rgfChatMemberStateChange & k_EChatMemberStateChangeEntered) {
        // A player joined the lobby
        CSteamID playerId(pCallback->m_ulSteamIDUserChanged);
        if (m_isHost && playerId != SteamUser()->GetSteamID()) {
            // If we're the host and someone else joined, that's our connected player
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
        if (playerId == m_connectedPlayerId) {
            // Our connected player left
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

            qDebug() << "SteamIntegration: Received message type:" << messageType
                     << "size:" << messageData.size() << "from:" << senderId.ConvertToUint64();

            // Mark P2P as initialized on first message from either side
            if (!m_p2pInitialized) {
                qDebug() << "SteamIntegration: P2P connection fully established!";
                m_p2pInitialized = true;

                // Start ping measurements once connection is established
                m_pingTimer.setInterval(2000);  // Measure ping every 2 seconds
                m_pingTimer.start();

                emit p2pInitialized();

                // Stop the ping timer if it's running
                m_p2pInitTimer.stop();
            }

            switch (messageType) {
            case 'P': // Ping/Pong
                if (messageData.startsWith("PING|")) {
                    handlePingRequest(messageData);
                } else if (messageData.startsWith("PONG|")) {
                    handlePingResponse(messageData);
                } else if (messageData == "PING") {
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

bool SteamIntegration::sendGameAction(const QString& actionType, int cellIndex)
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid()) {
        qDebug() << "SteamIntegration: Cannot send game action - not initialized, not in game, or no connected player";
        return false;
    }

    // Format: A|actionType|cellIndex
    QByteArray data;
    data.append('A');
    data.append(actionType.toUtf8());
    data.append('|');
    data.append(QByteArray::number(cellIndex));

    qDebug() << "SteamIntegration: Sending game action:" << actionType
             << "for cell:" << cellIndex << "to:" << m_connectedPlayerId.ConvertToUint64();

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
    // Parse action: actionType|cellIndex
    QList<QByteArray> parts = data.split('|');
    if (parts.size() != 2) {
        qDebug() << "SteamIntegration: Invalid game action format";
        return;
    }

    QString actionType = QString::fromUtf8(parts[0]);
    bool ok;
    int cellIndex = parts[1].toInt(&ok);

    if (ok) {
        qDebug() << "SteamIntegration: Received game action:" << actionType << "for cell:" << cellIndex;
        emit gameActionReceived(actionType, cellIndex);
    } else {
        qDebug() << "SteamIntegration: Invalid cell index in game action";
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

    qDebug() << "SteamIntegration: JSON data size:" << data.size();
    qDebug() << "SteamIntegration: First 100 chars:" << (data.size() > 100 ? data.left(100) : data);
    qDebug() << "SteamIntegration: Mines array in JSON:" << doc.object()["mines"].isArray()
             << "size:" << (doc.object()["mines"].isArray() ? doc.object()["mines"].toArray().size() : -1);
    qDebug() << "SteamIntegration: Numbers array in JSON:" << doc.object()["numbers"].isArray()
             << "size:" << (doc.object()["numbers"].isArray() ? doc.object()["numbers"].toArray().size() : -1);
}

void SteamIntegration::sendP2PInitPing()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        m_p2pInitTimer.stop();
        return;
    }

    qDebug() << "SteamIntegration: Sending P2P initialization ping";

    // Create a simple ping message
    QByteArray data;
    data.append('P'); // P for Ping
    data.append("PING");

    // Send the ping - if it fails, we'll try again on next timer tick
    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendReliable
        );
}

void SteamIntegration::startP2PInitialization()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || m_p2pInitialized) {
        return;
    }

    qDebug() << "SteamIntegration: Starting P2P initialization process";
    m_p2pInitialized = false;

    // Start the ping timer - send pings until we get a response
    m_p2pInitTimer.setInterval(500); // Try every 500ms
    m_p2pInitTimer.start();

    if (m_p2pInitialized) {
        m_pingTimer.setInterval(2000);  // Measure ping every 2 seconds
        m_pingTimer.start();
    }
    // Send first ping immediately
    sendP2PInitPing();
}

void SteamIntegration::checkForPendingInvites()
{
    if (!m_initialized) {
        qDebug() << "SteamIntegration: Cannot check for pending invites - Steam not initialized";
        return;
    }

    if (m_inMultiplayerGame) {
        qDebug() << "SteamIntegration: Already in multiplayer game, not checking pending invites";
        return;
    }

    qDebug() << "SteamIntegration: Checking for pending invites...";

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

    qDebug() << "SteamIntegration: No pending invites found through automatic methods";
}

int SteamIntegration::getAvatarHandleForPlayerName(const QString& playerName) {
    if (!m_initialized)
        return 0;

    ISteamFriends* steamFriends = SteamFriends();
    if (!steamFriends)
        return 0;

    int friendCount = steamFriends->GetFriendCount(k_EFriendFlagImmediate);
    for (int i = 0; i < friendCount; i++) {
        CSteamID friendId = steamFriends->GetFriendByIndex(i, k_EFriendFlagImmediate);
        QString friendName = QString::fromUtf8(steamFriends->GetFriendPersonaName(friendId));

        if (friendName == playerName) {
            return steamFriends->GetSmallFriendAvatar(friendId);
        }
    }

    return 0;
}

void SteamIntegration::sendPingRequest()
{
    if (!m_initialized || !m_inMultiplayerGame || !m_connectedPlayerId.IsValid() || !m_p2pInitialized) {
        return;
    }
    // Generate unique ID for this ping request
    qint64 pingId = QDateTime::currentMSecsSinceEpoch();
    // Store send time with ID
    m_pendingPings[pingId] = QDateTime::currentDateTime();

    // Format: P|PING|timestamp
    QByteArray data;
    data.append('P');
    data.append("PING|");
    data.append(QByteArray::number(pingId));

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        data.constData(),
        data.size(),
        k_EP2PSendUnreliable  // Use unreliable for more accurate latency measurement
        );
}

void SteamIntegration::handlePingRequest(const QByteArray& data)
{
    // Extract ping ID
    QByteArray idPart = data.mid(5); // Skip "PING|"

    // Send PONG response with same ID
    QByteArray response;
    response.append('P');
    response.append("PONG|");
    response.append(idPart);

    SteamNetworking()->SendP2PPacket(
        m_connectedPlayerId,
        response.constData(),
        response.size(),
        k_EP2PSendUnreliable
        );
}

void SteamIntegration::handlePingResponse(const QByteArray& data)
{
    QByteArray idPart = data.mid(5); // Skip "PONG|"
    qint64 pingId = idPart.toLongLong();

    if (m_pendingPings.contains(pingId)) {
        QDateTime sendTime = m_pendingPings.take(pingId);
        int pingMs = sendTime.msecsTo(QDateTime::currentDateTime());

        m_currentPing = pingMs;
        emit pingUpdated();
    }
}

