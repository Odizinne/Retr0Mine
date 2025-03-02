#include "steamintegration.h"
#include <QDebug>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>

SteamIntegration::SteamIntegration(QObject *parent)
    : QObject(parent)
    , m_initialized(false)
    , m_inMultiplayerGame(false)
    , m_isHost(false)
    , m_isConnecting(false)
    , m_lobbyReady(false)
// Remove the STEAM_CALLBACK initializers - they're automatically handled by the macro
{
    // Read initial difficulty from settings
    QSettings settings("Odizinne", "Retr0Mine");
    m_difficulty = settings.value("difficulty", 0).toInt();

    initialize();

    // Setup periodic network message checking
    connect(&m_networkTimer, &QTimer::timeout, this, &SteamIntegration::processNetworkMessages);
    m_networkTimer.setInterval(50); // Check for network messages every 50ms
}

SteamIntegration::~SteamIntegration()
{
    // Make sure to clean up any active multiplayer session
    if (m_inMultiplayerGame) {
        leaveLobby();
    }

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

        // Stop network message processing
        m_networkTimer.stop();

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

    qDebug() << "SteamIntegration: CreateLobby API call handle:" << apiCall;
    if (apiCall == k_uAPICallInvalid) {
        qDebug() << "SteamIntegration: CreateLobby API call failed";
        emit connectionFailed("Failed to create Steam API call");
        return;
    }

    // Register the callback for this specific API call
    m_lobbyCreatedCallback.Set(apiCall, this, &SteamIntegration::OnLobbyCreated);
    qDebug() << "SteamIntegration: Registered callback for LobbyCreated_t";

    m_isConnecting = true;
    emit connectingStatusChanged();
}

void SteamIntegration::OnLobbyCreated(LobbyCreated_t *pCallback, bool bIOFailure)
{
    qDebug() << "SteamIntegration: OnLobbyCreated callback received";

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

    qDebug() << "SteamIntegration: Lobby setup complete, waiting for connections";
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
            friendList.append(name + ":" + id); // Format: "FriendName:SteamID"
        }
    }

    return friendList;
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

void SteamIntegration::joinLobbyWithFriend(const QString& friendIdStr)
{
    qDebug() << "SteamIntegration: Attempting to join friend's lobby:" << friendIdStr;
    if (!m_initialized || m_inMultiplayerGame) {
        qDebug() << "SteamIntegration: Cannot join lobby - not initialized or already in game";
        return;
    }

    uint64 friendId = friendIdStr.toULongLong();
    CSteamID steamFriendId(friendId);

    // Try to join if friend is in a Retr0Mine lobby
    if (SteamFriends()->GetFriendGamePlayed(steamFriendId, &m_friendGameInfo)) {
        if (m_friendGameInfo.m_gameID.AppID() == SteamUtils()->GetAppID()) {
            CSteamID lobbyId = m_friendGameInfo.m_steamIDLobby;
            if (lobbyId.IsValid()) {
                m_isConnecting = true;
                emit connectingStatusChanged();

                SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(lobbyId);
                m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);
                qDebug() << "SteamIntegration: Join friend's lobby call made, waiting for callback";
            }
        }
    }
}

void SteamIntegration::leaveLobby()
{
    qDebug() << "SteamIntegration: Leaving lobby";
    if (!m_initialized || !m_inMultiplayerGame)
        return;

    if (m_currentLobbyId.IsValid()) {
        SteamMatchmaking()->LeaveLobby(m_currentLobbyId);
    }

    // Close P2P sessions
    if (m_connectedPlayerId.IsValid()) {
        SteamNetworking()->CloseP2PSessionWithUser(m_connectedPlayerId);
    }

    m_networkTimer.stop();
    m_inMultiplayerGame = false;
    m_isHost = false;
    m_lobbyReady = false;
    m_connectedPlayerId = CSteamID();
    m_connectedPlayerName = "";

    emit multiplayerStatusChanged();
    emit hostStatusChanged();
    emit lobbyReadyChanged();
    emit connectedPlayerChanged();
    emit canInviteFriendChanged();

    // Update rich presence back to single player
    updateRichPresence();

    qDebug() << "SteamIntegration: Lobby left successfully";
}

void SteamIntegration::OnLobbyEntered(LobbyEnter_t *pCallback, bool bIOFailure)
{
    qDebug() << "SteamIntegration: OnLobbyEntered callback received";

    m_isConnecting = false;
    emit connectingStatusChanged();

    if (bIOFailure || pCallback->m_EChatRoomEnterResponse != k_EChatRoomEnterResponseSuccess) {
        qDebug() << "SteamIntegration: Failed to enter lobby, error:"
                 << (bIOFailure ? "I/O Failure" : QString::number(pCallback->m_EChatRoomEnterResponse));
        emit connectionFailed("Failed to enter lobby (error " +
                              QString(bIOFailure ? "I/O Failure" : QString::number(pCallback->m_EChatRoomEnterResponse)) + ")");
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
    // This callback is triggered when lobby data changes
    qDebug() << "SteamIntegration: Lobby data updated";

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

void SteamIntegration::OnGameOverlayActivated(GameOverlayActivated_t *pCallback)
{
    // This callback is triggered when the Steam overlay is opened/closed
    qDebug() << "SteamIntegration: Steam overlay " << (pCallback->m_bActive ? "activated" : "deactivated");

    // You can use this to pause the game when the overlay is active
    // pCallback->m_bActive is true when overlay is opened, false when closed
}

void SteamIntegration::OnGameLobbyJoinRequested(GameLobbyJoinRequested_t *pCallback)
{
    // This callback is triggered when the player accepts a lobby invite from Steam
    qDebug() << "SteamIntegration: Game lobby join requested for lobby:" << pCallback->m_steamIDLobby.ConvertToUint64();

    if (m_inMultiplayerGame) {
        // Already in a game, need to leave first
        qDebug() << "SteamIntegration: Already in a game, leaving first";
        leaveLobby();
    }

    // Join the requested lobby
    m_isConnecting = true;
    emit connectingStatusChanged();

    SteamAPICall_t apiCall = SteamMatchmaking()->JoinLobby(pCallback->m_steamIDLobby);
    m_lobbyEnteredCallback.Set(apiCall, this, &SteamIntegration::OnLobbyEntered);

    qDebug() << "SteamIntegration: Join requested lobby call made, waiting for callback";
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

            switch (messageType) {
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
}
