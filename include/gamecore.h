#pragma once

#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QTranslator>
#include <QPalette>

class GameCore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool gamescope READ isGamescope CONSTANT)
    Q_PROPERTY(int languageIndex READ getLanguageIndex NOTIFY languageIndexChanged)
    Q_PROPERTY(QString qtVersion READ getQtVersion CONSTANT)
    Q_PROPERTY(bool darkMode READ getDarkMode CONSTANT)

public:
    explicit GameCore(QObject *parent = nullptr);
    ~GameCore() override;

    void init();
    Q_INVOKABLE void setThemeColorScheme(int ColorSchemeIndex);
    Q_INVOKABLE void setLanguage(int index);
    Q_INVOKABLE void deleteSaveFile(const QString &filename);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename);
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void restartRetr0Mine(int index);
    Q_INVOKABLE void resetRetr0Mine();
    Q_INVOKABLE bool saveLeaderboard(const QString &data) const;
    Q_INVOKABLE QString loadLeaderboard() const;
    Q_INVOKABLE void setApplicationPalette(int systemAccent);

    bool isGamescope() const { return isRunningOnGamescope; }
    int getLanguageIndex() const { return m_languageIndex; }
    QString getQtVersion() const { return QT_VERSION_STR; }
    bool getDarkMode() const { return false; }

    QSettings settings;

private:
    QTranslator *translator;

    bool isRunningOnGamescope;
    bool loadLanguage(QString languageCode);
    QString getLeaderboardPath() const;
    int m_languageIndex;
    int selectedAccentColor;
    void setCustomPalette();
    void setSystemPalette();

signals:
    void languageIndexChanged();
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
    inline static QJSEngine* s_engine = nullptr;

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
