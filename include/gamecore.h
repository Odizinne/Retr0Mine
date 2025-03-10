#pragma once

#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QTranslator>

class GameCore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool showWelcome READ getShowWelcome CONSTANT)
    Q_PROPERTY(bool gamescope READ isGamescope CONSTANT)
    Q_PROPERTY(int languageIndex READ getLanguageIndex NOTIFY languageIndexChanged)
    Q_PROPERTY(bool isFluent READ getIsFluent NOTIFY fluentChanged)
    Q_PROPERTY(bool isUniversal READ getIsUniversal NOTIFY universalChanged)

public:
    explicit GameCore(QObject *parent = nullptr);
    ~GameCore() override;

    // Initial setup methods
    void init();
    void setQMLStyle(int index);
    Q_INVOKABLE void setThemeColorScheme(int ColorSchemeIndex);
    Q_INVOKABLE void setLanguage(int index);

    // Getter methods for engine setup
    bool shouldResetSettings() const { return !settings.value("welcomeMessageShown", false).toBool(); }

    // QML invokable methods
    Q_INVOKABLE void deleteSaveFile(const QString &filename);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename);
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void restartRetr0Mine(int index);
    Q_INVOKABLE void resetRetr0Mine();
    Q_INVOKABLE bool saveLeaderboard(const QString &data) const;
    Q_INVOKABLE QString loadLeaderboard() const;
    Q_INVOKABLE void resetSettings();

    // Property getters
    bool getShowWelcome() const { return shouldShowWelcomeMessage; }
    bool isGamescope() const { return isRunningOnGamescope; }
    int getLanguageIndex() const { return m_languageIndex; }
    bool getIsFluent() const { return m_isFluent; }
    bool getIsUniversal() const { return m_isUniversal; }

    QSettings settings;
private:
    QTranslator *translator;

    bool isRunningOnGamescope;
    bool shouldShowWelcomeMessage;
    bool loadLanguage(QString languageCode);
    QString getLeaderboardPath() const;
    int m_languageIndex;
    bool m_isFluent = true;
    bool m_isUniversal = false;
    void checkAndCorrectPalette();

signals:
    void languageIndexChanged();
    void fluentChanged();
    void universalChanged();
    void saveCompleted(bool success);
};

struct GameCoreForeign
{
    Q_GADGET
    QML_FOREIGN(GameCore)
    QML_SINGLETON
    QML_NAMED_ELEMENT(GameCore)
public:
    inline static GameCore* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;  // Moved to public

    static GameCore* create(QQmlEngine*, QJSEngine* engine)
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
