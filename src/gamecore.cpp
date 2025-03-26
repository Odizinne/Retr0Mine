#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QStyleHints>
#include <QWindow>
#include "gamecore.h"
#include "steamintegration.h"

#ifdef _WIN32
#include <windows.h>
#include <dwmapi.h>
#pragma comment(lib, "dwmapi.lib")
#endif

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
    int colorSchemeIndex = settings.value("colorSchemeIndex").toInt();
    int styleIndex = settings.value("themeIndex", 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();

    setThemeColorScheme(colorSchemeIndex);
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
    settings.clear();
    QMetaObject::invokeMethod(this, [this]() {
        settings.sync();
        QProcess::startDetached(QGuiApplication::applicationFilePath(), QGuiApplication::arguments());
        QGuiApplication::quit();
    }, Qt::QueuedConnection);
}

void GameCore::restartRetr0Mine() {
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


bool GameCore::setTitlebarColor(int colorMode) {
#ifdef _WIN32
    if (colorMode == m_titlebarColorMode) {
        return true;
    }

    m_titlebarColorMode = colorMode;
    bool success = true;

    for (QWindow* window : QGuiApplication::topLevelWindows()) {
        HWND hwnd = (HWND)window->winId();
        if (!hwnd) {
            success = false;
            continue;
        }

        bool windowSuccess = false;

        COLORREF color = (colorMode == 0) ? RGB(0, 0, 0) : RGB(255, 255, 255);
        HRESULT hr = DwmSetWindowAttribute(hwnd, 35, &color, sizeof(color));

        if (SUCCEEDED(hr)) {
            windowSuccess = true;
        } else {
            BOOL darkMode = (colorMode == 0) ? TRUE : FALSE;
            hr = DwmSetWindowAttribute(hwnd, 20, &darkMode, sizeof(darkMode));
            windowSuccess = SUCCEEDED(hr);
        }

        if (!windowSuccess) {
            success = false;
        }
    }

    static bool connected = false;
    if (!connected) {
        connected = true;
        QObject::connect(qApp, &QGuiApplication::focusWindowChanged, [this](QWindow* window) {
            if (window) {
                HWND hwnd = (HWND)window->winId();
                if (hwnd) {
                    COLORREF color = (m_titlebarColorMode == 0) ? RGB(0, 0, 0) : RGB(255, 255, 255);
                    HRESULT hr = DwmSetWindowAttribute(hwnd, 35, &color, sizeof(color));

                    if (!SUCCEEDED(hr)) {
                        BOOL darkMode = (m_titlebarColorMode == 0) ? TRUE : FALSE;
                        DwmSetWindowAttribute(hwnd, 20, &darkMode, sizeof(darkMode));
                    }
                }
            }
        });
    }

    return success;
#else
    // Not on Windows, so no effect
    m_titlebarColorMode = colorMode;
    return false;
#endif
}

QString GameCore::getRenderingBackend() {
    QSettings settings;
    int backend = settings.value("renderingBackend", 0).toInt();

#ifdef Q_OS_WIN
    // Windows platform
    switch (backend) {
    case 0:
        return "opengl";
    case 1:
        return "d3d11";
    case 2:
        return "d3d12";
    default:
        return "opengl";
    }
#else
    // Linux and other platforms
    switch (backend) {
    case 0:
        return "opengl";
    case 1:
        return "vulkan";
    default:
        return "opengl";
    }
#endif
}
