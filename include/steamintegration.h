#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QSettings>
#include <steam/steam_api_common.h>
#include <steam/isteamfriends.h>
#include <steam/isteamuser.h>
#include <steam/isteamnetworking.h>
#include <steam/isteammatchmaking.h>

class SteamIntegration : public QObject
{
    Q_OBJECT
    // Existing properties
    Q_PROPERTY(bool unlockedFlag1 READ getUnlockedFlag1 CONSTANT)
    Q_PROPERTY(bool unlockedFlag2 READ getUnlockedFlag2 CONSTANT)
    Q_PROPERTY(bool unlockedFlag3 READ getUnlockedFlag3 CONSTANT)
    Q_PROPERTY(bool unlockedAnim1 READ getUnlockedAnim1 CONSTANT)
    Q_PROPERTY(bool unlockedAnim2 READ getUnlockedAnim2 CONSTANT)
    Q_PROPERTY(QString playerName READ getPlayerName NOTIFY playerNameChanged)
    Q_PROPERTY(bool initialized READ isInitialized CONSTANT)
    Q_PROPERTY(int difficulty MEMBER m_difficulty WRITE setDifficulty)

    // New multiplayer properties
    Q_PROPERTY(bool isInMultiplayerGame READ isInMultiplayerGame NOTIFY multiplayerStatusChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY hostStatusChanged)
    Q_PROPERTY(QString connectedPlayerName READ getConnectedPlayerName NOTIFY connectedPlayerChanged)
    Q_PROPERTY(bool isConnecting READ isConnecting NOTIFY connectingStatusChanged)
    Q_PROPERTY(bool isLobbyReady READ isLobbyReady NOTIFY lobbyReadyChanged)
    Q_PROPERTY(bool canInviteFriend READ canInviteFriend NOTIFY canInviteFriendChanged)
    Q_PROPERTY(bool isP2PConnected READ isP2PConnected NOTIFY p2pInitialized)

public:
    explicit SteamIntegration(QObject *parent = nullptr);
    ~SteamIntegration();

    // Existing methods
    bool initialize();
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void unlockAchievement(const QString &achievementId);
    Q_INVOKABLE bool isAchievementUnlocked(const QString &achievementId) const;
    Q_INVOKABLE bool isRunningOnDeck() const;
    Q_INVOKABLE bool incrementTotalWin();
    QString getSteamUILanguage() const;
    QString getPlayerName() const { return m_playerName; }
    bool isInitialized() const { return m_initialized; }

    // Rich presence related
    void setDifficulty(int difficulty);
    Q_INVOKABLE void updateRichPresence();
    QString getDifficultyString() const;

    // Getters for achievements
    bool getUnlockedFlag1() const { return isAchievementUnlocked("ACH_NO_HINT_EASY"); }
    bool getUnlockedFlag2() const { return isAchievementUnlocked("ACH_NO_HINT_MEDIUM"); }
    bool getUnlockedFlag3() const { return isAchievementUnlocked("ACH_NO_HINT_HARD"); }
    bool getUnlockedAnim1() const { return isAchievementUnlocked("ACH_HINT_MASTER"); }
    bool getUnlockedAnim2() const { return isAchievementUnlocked("ACH_SPEED_DEMON"); }

    // New multiplayer methods
    // Lobby management
    Q_INVOKABLE void createLobby();
    Q_INVOKABLE void leaveLobby();
    Q_INVOKABLE void cleanupMultiplayerSession(bool isShuttingDown = false);
    Q_INVOKABLE QStringList getOnlineFriends();
    Q_INVOKABLE QString getAvatarImageForHandle(int handle);
    Q_INVOKABLE int getAvatarHandleForPlayerName(const QString& playerName);
    Q_INVOKABLE void inviteFriend(const QString& friendId);
    Q_INVOKABLE void acceptInvite(const QString& lobbyId);
    Q_INVOKABLE void checkForPendingInvites();

    // P2P networking
    Q_INVOKABLE bool sendGameAction(const QString& actionType, int cellIndex);
    Q_INVOKABLE bool sendGameState(const QVariantMap& gameState);

    // Callback processing - call this regularly
    Q_INVOKABLE void runCallbacks();

    // Multiplayer status getters
    bool isInMultiplayerGame() const { return m_inMultiplayerGame; }
    bool isHost() const { return m_isHost; }
    bool isConnecting() const { return m_isConnecting; }
    QString getConnectedPlayerName() const { return m_connectedPlayerName; }
    bool isLobbyReady() const { return m_lobbyReady; }
    bool canInviteFriend() const { return m_initialized && m_inMultiplayerGame && m_isHost; }
    bool isP2PConnected() const { return m_p2pInitialized; }
    void startP2PInitialization();

private:
    // Existing members
    bool m_initialized;
    QString m_playerName;
    int m_difficulty;
    void updatePlayerName();

    // Call result callbacks for specific API calls
    CCallResult<SteamIntegration, LobbyCreated_t> m_lobbyCreatedCallback;
    CCallResult<SteamIntegration, LobbyEnter_t> m_lobbyEnteredCallback;

    // Steam Callbacks for events
    STEAM_CALLBACK(SteamIntegration, OnLobbyDataUpdate, LobbyDataUpdate_t);
    STEAM_CALLBACK(SteamIntegration, OnLobbyChatUpdate, LobbyChatUpdate_t);
    STEAM_CALLBACK(SteamIntegration, OnP2PSessionRequest, P2PSessionRequest_t);
    STEAM_CALLBACK(SteamIntegration, OnP2PSessionConnectFail, P2PSessionConnectFail_t);
    STEAM_CALLBACK(SteamIntegration, OnGameLobbyJoinRequested, GameLobbyJoinRequested_t);
    STEAM_CALLBACK(SteamIntegration, OnLobbyInvite, LobbyInvite_t);
    // Callback handlers for specific API calls
    void OnLobbyCreated(LobbyCreated_t* pCallback, bool bIOFailure);
    void OnLobbyEntered(LobbyEnter_t* pCallback, bool bIOFailure);

    // Network message handling
    void processNetworkMessages();
    void handleGameAction(const QByteArray& data);
    void handleGameState(const QByteArray& data);
    void sendP2PInitPing();
    // Multiplayer state
    CSteamID m_currentLobbyId;
    CSteamID m_connectedPlayerId;
    bool m_inMultiplayerGame;
    bool m_isHost;
    bool m_isConnecting;
    bool m_lobbyReady;
    bool m_p2pInitialized;
    QTimer m_p2pInitTimer;
    QString m_connectedPlayerName;
    QTimer m_networkTimer;

    // For invite handling
    FriendGameInfo_t m_friendGameInfo;

signals:
    // Existing signals
    void playerNameChanged();

    // New multiplayer signals
    void multiplayerStatusChanged();
    void hostStatusChanged();
    void connectedPlayerChanged();
    void connectingStatusChanged();
    void lobbyReadyChanged();
    void canInviteFriendChanged();
    void gameActionReceived(QString actionType, int cellIndex);
    void gameStateReceived(QVariantMap gameState);
    void connectionFailed(QString reason);
    void connectionSucceeded();
    void p2pInitialized();
    void inviteReceived(QString friendName, QString connectString);
};

struct SteamIntegrationForeign
{
    Q_GADGET
    QML_FOREIGN(SteamIntegration)
    QML_SINGLETON
    QML_NAMED_ELEMENT(SteamIntegration)
public:
    inline static SteamIntegration* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;

    static SteamIntegration* create(QQmlEngine*, QJSEngine* engine)
    {
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
