#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QSettings>
#include <QDateTime>
#include <steam/steam_api_common.h>
#include <steam/isteamfriends.h>
#include <steam/isteamuser.h>
#include <steam/isteamnetworking.h>
#include <steam/isteammatchmaking.h>

class SteamIntegration : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool unlockedFlag1 READ getUnlockedFlag1 CONSTANT)
    Q_PROPERTY(bool unlockedFlag2 READ getUnlockedFlag2 CONSTANT)
    Q_PROPERTY(bool unlockedFlag3 READ getUnlockedFlag3 CONSTANT)
    Q_PROPERTY(bool unlockedAnim1 READ getUnlockedAnim1 CONSTANT)
    Q_PROPERTY(bool unlockedAnim2 READ getUnlockedAnim2 CONSTANT)
    Q_PROPERTY(QString playerName READ getPlayerName NOTIFY playerNameChanged)
    Q_PROPERTY(bool initialized READ isInitialized CONSTANT)
    Q_PROPERTY(int difficulty MEMBER m_difficulty WRITE setDifficulty)

    Q_PROPERTY(bool isInMultiplayerGame READ isInMultiplayerGame NOTIFY multiplayerStatusChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY hostStatusChanged)
    Q_PROPERTY(QString connectedPlayerName READ getConnectedPlayerName NOTIFY connectedPlayerChanged)
    Q_PROPERTY(bool isConnecting READ isConnecting NOTIFY connectingStatusChanged)
    Q_PROPERTY(bool isLobbyReady READ isLobbyReady NOTIFY lobbyReadyChanged)
    Q_PROPERTY(bool canInviteFriend READ canInviteFriend NOTIFY canInviteFriendChanged)
    Q_PROPERTY(bool isP2PConnected READ isP2PConnected NOTIFY p2pInitialized)

    Q_PROPERTY(ConnectionState connectionState READ getConnectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(int pingTime READ getPingTime NOTIFY pingTimeChanged)

public:
    static bool debugLoggingEnabled;
    enum ConnectionState {
        Disconnected,
        Connecting,
        Connected,
        Unstable,
        Reconnecting
    };
    Q_ENUM(ConnectionState)

    explicit SteamIntegration(QObject *parent = nullptr);
    ~SteamIntegration();

    bool initialize();
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void unlockAchievement(const QString &achievementId);
    Q_INVOKABLE bool isAchievementUnlocked(const QString &achievementId) const;
    Q_INVOKABLE bool isRunningOnDeck() const;
    Q_INVOKABLE bool incrementTotalWin();
    QString getSteamUILanguage() const;
    QString getPlayerName() const { return m_playerName; }
    bool isInitialized() const { return m_initialized; }

    void setDifficulty(int difficulty);
    Q_INVOKABLE void updateRichPresence();
    QString getDifficultyString() const;

    bool getUnlockedFlag1() const { return isAchievementUnlocked("ACH_NO_HINT_EASY"); }
    bool getUnlockedFlag2() const { return isAchievementUnlocked("ACH_NO_HINT_MEDIUM"); }
    bool getUnlockedFlag3() const { return isAchievementUnlocked("ACH_NO_HINT_HARD"); }
    bool getUnlockedAnim1() const { return isAchievementUnlocked("ACH_HINT_MASTER"); }
    bool getUnlockedAnim2() const { return isAchievementUnlocked("ACH_SPEED_DEMON"); }

    Q_INVOKABLE void createLobby();
    Q_INVOKABLE void leaveLobby();
    Q_INVOKABLE void cleanupMultiplayerSession(bool isShuttingDown = false);
    Q_INVOKABLE QStringList getOnlineFriends();
    Q_INVOKABLE QString getAvatarImageForHandle(int handle);
    Q_INVOKABLE int getAvatarHandleForPlayerName(const QString& playerName);
    Q_INVOKABLE void inviteFriend(const QString& friendId);
    Q_INVOKABLE void acceptInvite(const QString& lobbyId);
    Q_INVOKABLE void checkForPendingInvites();

    Q_INVOKABLE bool sendGameAction(const QString& actionType, const QVariant& parameter);
    Q_INVOKABLE bool sendGameState(const QVariantMap& gameState);
    Q_INVOKABLE void requestReconnection();
    Q_INVOKABLE void tryReconnect();

    Q_INVOKABLE bool testConnection();
    Q_INVOKABLE bool forcePing();
    Q_INVOKABLE void measurePing();

    Q_INVOKABLE void runCallbacks();

    bool isInMultiplayerGame() const { return m_inMultiplayerGame; }
    bool isHost() const { return m_isHost; }
    bool isConnecting() const { return m_isConnecting; }
    QString getConnectedPlayerName() const { return m_connectedPlayerName; }
    bool isLobbyReady() const { return m_lobbyReady; }
    bool canInviteFriend() const { return m_initialized && m_inMultiplayerGame && m_isHost; }
    bool isP2PConnected() const { return m_p2pInitialized; }

    ConnectionState getConnectionState() const { return m_connectionState; }
    int getPingTime() const { return m_pingTime; }

    void startP2PInitialization();

private:
    bool m_initialized;
    QString m_playerName;
    int m_difficulty;
    void updatePlayerName();

    CCallResult<SteamIntegration, LobbyCreated_t> m_lobbyCreatedCallback;
    CCallResult<SteamIntegration, LobbyEnter_t> m_lobbyEnteredCallback;

    STEAM_CALLBACK(SteamIntegration, OnLobbyDataUpdate, LobbyDataUpdate_t);
    STEAM_CALLBACK(SteamIntegration, OnLobbyChatUpdate, LobbyChatUpdate_t);
    STEAM_CALLBACK(SteamIntegration, OnP2PSessionRequest, P2PSessionRequest_t);
    STEAM_CALLBACK(SteamIntegration, OnP2PSessionConnectFail, P2PSessionConnectFail_t);
    STEAM_CALLBACK(SteamIntegration, OnGameLobbyJoinRequested, GameLobbyJoinRequested_t);
    STEAM_CALLBACK(SteamIntegration, OnLobbyInvite, LobbyInvite_t);

    void OnLobbyCreated(LobbyCreated_t* pCallback, bool bIOFailure);
    void OnLobbyEntered(LobbyEnter_t* pCallback, bool bIOFailure);

    void processNetworkMessages();
    bool handleSystemMessage(const QByteArray& data);
    bool handleGameAction(const QByteArray& data);
    bool handleGameState(const QByteArray& data);
    void sendP2PInitPing();
    void sendHeartbeat();
    void sendSystemMessage(const QString& type, const QVariantMap& data = QVariantMap());
    void updateConnectionState(ConnectionState newState);

    CSteamID m_currentLobbyId;
    CSteamID m_connectedPlayerId;
    bool m_inMultiplayerGame;
    bool m_isHost;
    bool m_isConnecting;
    bool m_lobbyReady;
    bool m_p2pInitialized;
    ConnectionState m_connectionState;
    QTimer m_p2pInitTimer;
    QTimer m_heartbeatTimer;
    QTimer m_networkTimer;
    QString m_connectedPlayerName;
    int m_lastMessageTime;
    int m_pingTime;
    int m_lastPingSent;
    int m_missedHeartbeats;

    bool m_attemptingReconnection;
    int m_reconnectionAttempts;
    QTimer m_reconnectionTimer;
    static const int MAX_RECONNECTION_ATTEMPTS = 5;

    QTimer m_connectionHealthTimer;
    int m_connectionCheckFailCount;
    static const int MAX_CONNECTION_FAILURES = 3;
    static const int MAX_MISSED_HEARTBEATS = 3;
    static const int HEARTBEAT_INTERVAL = 2000;
    void checkConnectionHealth();
    void resetConnectionHealth();

    FriendGameInfo_t m_friendGameInfo;

    void handlePingPongMessage(const QByteArray& messageData, const CSteamID& senderId);

signals:
    void playerNameChanged();

    void multiplayerStatusChanged();
    void hostStatusChanged();
    void connectedPlayerChanged();
    void connectingStatusChanged();
    void lobbyReadyChanged();
    void canInviteFriendChanged();
    void gameActionReceived(QString actionType, QVariant parameter);
    void gameStateReceived(QVariantMap gameState);
    void connectionFailed(QString reason);
    void connectionSucceeded();
    void p2pInitialized();
    void inviteReceived(QString friendName, QString connectString);
    void notifyConnectionLost(QString message);

    void connectionStateChanged(ConnectionState state);
    void pingTimeChanged(int pingTime);
    void reconnectionFailed();
    void reconnectionSucceeded();
    void connectionUnstable();
};

struct SteamIntegrationForeign {
    Q_GADGET
    QML_FOREIGN(SteamIntegration)
    QML_SINGLETON
    QML_NAMED_ELEMENT(SteamIntegration)
public:
    inline static SteamIntegration* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;

    static SteamIntegration* create(QQmlEngine*, QJSEngine* engine) {
        Q_ASSERT(s_singletonInstance);
        Q_ASSERT(engine->thread() == s_singletonInstance->thread());
        if (s_engine)
            Q_ASSERT(engine == s_engine);
        else
            s_engine = engine;
        QJSEngine::setObjectOwnership(s_singletonInstance, QJSEngine::CppOwnership);
        return s_singletonInstance;
    }
};
