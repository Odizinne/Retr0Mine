#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcessEnvironment>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QStyleHints>
#include "gamecore.h"
#include "steamintegration.h"

namespace {
const QMap<QString, QString>& getSteamLanguageMap() {
    static const QMap<QString, QString> map {
        {"english", "en"},
        {"french", "fr"}
    };
    return map;
}

const QMap<QString, QString>& getSystemLanguageMap() {
    static const QMap<QString, QString> map {
        {"en", "en"},
        {"fr", "fr"}
    };
    return map;
}

const QMap<int, QString>& getLanguageIndexMap() {
    static const QMap<int, QString> map {
        {1, "en"},
        {2, "fr"}
    };
    return map;
}
}

GameCore::GameCore(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , translator(new QTranslator(this))
    , isRunningOnGamescope(false)
    , shouldShowWelcomeMessage(false)
{
    QString desktop = QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP");
    isRunningOnGamescope = desktop.toLower() == "gamescope";
}

GameCore::~GameCore() {
    if (translator) {
        translator->deleteLater();
    }
}

void GameCore::init() {
    if (!settings.value("welcomeMessageShown", false).toBool()) {
        resetSettings();
    }

    int colorSchemeIndex = settings.value("colorSchemeIndex").toInt();
    int styleIndex = settings.value("themeIndex", 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();
    bool systemAccent = settings.value("systemAccent", false).toBool();

    setThemeColorScheme(colorSchemeIndex);
    setQMLStyle(styleIndex);
    setLanguage(languageIndex);
}

void GameCore::setThemeColorScheme(int colorSchemeIndex) {
#ifdef _WIN32
    switch(colorSchemeIndex) {
    case(0):
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Unknown);
        break;
    case(1):
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
        break;
    case(2):
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Light);
        break;
    default:
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Unknown);
        break;
    }
#endif
}

void GameCore::setApplicationPalette(int systemAccent) {
    selectedAccentColor = systemAccent;
    disconnect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
               this, &GameCore::setCustomPalette);
    if (systemAccent == 0) {
        setSystemPalette();
    } else {
        setCustomPalette();
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
                this, &GameCore::setCustomPalette);
    }
}

void GameCore::setSystemPalette() {
    QGuiApplication::setPalette(QPalette());
}

void GameCore::setCustomPalette() {
    QPalette palette;
    QColor accentColor;
    QColor highlight;

    bool isDarkMode = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    // If running on Gamescope, always use dark mode colors
    if (isRunningOnGamescope) {
        isDarkMode = true;
    }

    switch (selectedAccentColor) {
    case 1:
        accentColor = isDarkMode ? "#4CC2FF" : "#003E92";
        highlight = "#0078D4";
        break;
    case 2:
        accentColor = isDarkMode ? "#FFB634" : "#A14600";
        highlight = "#FF8C00";
        break;
    case 3:
        accentColor = isDarkMode ? "#F46762" : "#9E0912";
        highlight = "#E81123";
        break;
    case 4:
        accentColor = isDarkMode ? "#45E532" : "#084B08";
        highlight = "#107C10";
        break;
    case 5:
        accentColor = isDarkMode ? "#D88DE1" : "#6F2382";
        highlight = "#B146C2";
        break;
    default:
        accentColor = isDarkMode ? "#4CC2FF" : "#003E92";
        highlight = "#0078D4";
        break;
    }

    palette.setColor(QPalette::ColorRole::Accent, accentColor);
    palette.setColor(QPalette::ColorRole::Highlight, highlight);
    QGuiApplication::setPalette(palette);
}

void GameCore::resetSettings() {
    settings.setValue("startFullScreen", isRunningOnGamescope ? true : false);
    settings.setValue("themeIndex", 0);
    settings.setValue("languageIndex", 0);
    settings.setValue("difficulty", 0);
    settings.setValue("invertLRClick", false);
    settings.setValue("autoreveal", true);
    settings.setValue("enableQuestionMarks", true);
    settings.setValue("enableSafeQuestionMarks", false);
    settings.setValue("loadLastGame", false);
    settings.setValue("soundEffects", true);
    settings.setValue("volume", 1.0);
    settings.setValue("soundPackIndex", 2);
    settings.setValue("animations", true);
    settings.setValue("cellFrame", true);
    settings.setValue("contrastFlag", false);
    settings.setValue("customWidth", 8);
    settings.setValue("customHeight", 8);
    settings.setValue("customMines", 10);
    settings.setValue("dimSatisfied", false);
    settings.setValue("colorBlindness", 0);
    settings.setValue("flagSkinIndex", 0);
    settings.setValue("colorSchemeIndex", 0);
    settings.setValue("gridResetAnimationIndex", 0);
    settings.setValue("fontIndex", 0);
    settings.setValue("satisfiedOpacity", 0.5);
    settings.setValue("displayTimer", true);
    settings.setValue("safeFirstClick", true);
    settings.setValue("pingColorIndex", 0);
    settings.setValue("mpPlayerColoredFlags", true);
    settings.setValue("localFlagColorIndex", 4);
    settings.setValue("remoteFlagColorIndex", 1);
    settings.setValue("mpShowInviteNotificationInGame", true);
    settings.setValue("mpAudioNotificationOnNewMessage", true);
    settings.setValue("shakeUnifinishedNumbers", true);
    settings.setValue("hintReasoningInChat", true);
    settings.setValue("remoteVolume", 0.7);
    settings.setValue("accentColorIndex", 2);
    settings.setValue("gridScale", 1);

    settings.setValue("welcomeMessageShown", true);
    shouldShowWelcomeMessage = true;
}

void GameCore::setQMLStyle(int index) {
    QString style;
    m_isFluent = false;
    m_isUniversal = false;

    switch(index) {
    case 0:
        style = "FluentWinUI3";
        m_isFluent = true;
        break;
    case 1:
        style = "Universal";
        m_isUniversal = true;
        break;
    default:
        style = "FluentWinUI3";
        m_isFluent = true;
        break;
    }

    QQuickStyle::setStyle(style);

    emit fluentChanged();
    emit universalChanged();
}

void GameCore::setLanguage(int index) {
    QString languageCode;
    if (index == 0) {
        if (SteamIntegrationForeign::s_singletonInstance->isInitialized()) {
            languageCode = getSteamLanguageMap().value(
                SteamIntegrationForeign::s_singletonInstance->getSteamUILanguage().toLower(),
                "en"
                );
        } else {
            QLocale locale;
            languageCode = getSystemLanguageMap().value(locale.name(), "en");
        }
    } else {
        languageCode = getLanguageIndexMap().value(index, "en");
    }
    loadLanguage(languageCode);
    if (qApp) {
        qApp->installTranslator(translator);
        if (GameCoreForeign::s_engine) {
            static_cast<QQmlEngine*>(GameCoreForeign::s_engine)->retranslate();
        }
    }
    m_languageIndex = index;
    emit languageIndexChanged();
}

bool GameCore::loadLanguage(QString languageCode) {
    if (qApp) {
        qApp->removeTranslator(translator);
    }

    delete translator;
    translator = new QTranslator(this);

    QString filePath = ":/i18n/Retr0Mine_" + languageCode + ".qm";

    if (translator->load(filePath)) {
        if (qApp) {
            qApp->installTranslator(translator);
        }
        return true;
    }

    return false;
}

void GameCore::resetRetr0Mine() {
    settings.setValue("welcomeMessageShown", false);
    QMetaObject::invokeMethod(this, [this]() {
        settings.sync();
        QProcess::startDetached(QGuiApplication::applicationFilePath(), QGuiApplication::arguments());
        QGuiApplication::quit();
    }, Qt::QueuedConnection);
}

void GameCore::restartRetr0Mine(int index) {
    settings.setValue("themeIndex", index);
    QMetaObject::invokeMethod(this, [this]() {
        settings.sync();
        QProcess::startDetached(QGuiApplication::applicationFilePath(), QGuiApplication::arguments());
        QGuiApplication::quit();
    }, Qt::QueuedConnection);
}

QStringList GameCore::getSaveFiles() const {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }
    QStringList files = saveDir.entryList(QStringList() << "*.json", QDir::Files);
    files.removeAll("leaderboard.json");
    return files;
}

bool GameCore::saveGameState(const QString &data, const QString &filename) {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }
    QFile file(saveDir.filePath(filename));
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << data;
        stream.flush();
        file.close();
        emit saveCompleted(true);
        return true;
    }
    emit saveCompleted(false);
    return false;
}

QString GameCore::loadGameState(const QString &filename) const {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    QFile file(QDir(savePath).filePath(filename));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString data = stream.readAll();
        file.close();
        return data;
    }
    return QString();
}

void GameCore::deleteSaveFile(const QString &filename) {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    QString fullPath = saveDir.filePath(filename);
    QFile::remove(fullPath);
}

QString GameCore::getLeaderboardPath() const {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(savePath).filePath("leaderboard.json");
}

bool GameCore::saveLeaderboard(const QString &data) const {
    QString filePath = getLeaderboardPath();
    QDir saveDir = QFileInfo(filePath).dir();

    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << data;
        file.close();
        return true;
    }
    return false;
}

QString GameCore::loadLeaderboard() const {
    QFile file(getLeaderboardPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString data = stream.readAll();
        file.close();
        return data;
    }
    return QString();
}
