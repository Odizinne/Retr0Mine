#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QStyleHints>
#include <QWindow>
#include <QScreen>
#include "gamecore.h"
#include "steamintegration.h"

#ifdef _WIN32
#include <windows.h>
#include <dwmapi.h>
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

    if (!settings.contains("firstRunCompleted")) {
        settings.setValue("firstRunCompleted", false);
    }

    QGuiApplication::instance()->installEventFilter(this);

    QString logPath = getLogFilePath();
    QDir logDir(logPath);
    if (!logDir.exists()) {
        logDir.mkpath(".");
    }

    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_hh-mm-ss");
    m_currentLogFile = QDir(logPath).filePath(timestamp + ".log");

    cleanupOldLogFiles(10);

    writeToLogFile("=== Retr0Mine Log Started: " + QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss") + " ===");
    writeToLogFile("App Version: 1.0");
    writeToLogFile("Qt Version: " + QString(QT_VERSION_STR));
    writeToLogFile("Platform: " + QGuiApplication::platformName());
    writeToLogFile("==============================================");
}

GameCore::~GameCore() {
    if (translator) {
        translator->deleteLater();
    }
}

void GameCore::init() {
    int colorSchemeIndex = settings.value("colorSchemeIndex").toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();
    bool customCursor = settings.value("customCursor", true).toBool();

    setThemeColorScheme(colorSchemeIndex);
    setLanguage(languageIndex);
    setCursor(customCursor);
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
        accentColor = isDarkMode ? QColor(76, 194, 255) : QColor(0, 62, 146);  // #4CC2FF : #003E92
        highlight = QColor(0, 120, 212);  // #0078D4
        break;
    case 2:
        accentColor = isDarkMode ? QColor(255, 182, 52) : QColor(161, 70, 0);  // #FFB634 : #A14600
        highlight = QColor(255, 140, 0);  // #FF8C00
        break;
    case 3:
        accentColor = isDarkMode ? QColor(244, 103, 98) : QColor(158, 9, 18);  // #F46762 : #9E0912
        highlight = QColor(232, 17, 35);  // #E81123
        break;
    case 4:
        accentColor = isDarkMode ? QColor(69, 229, 50) : QColor(8, 75, 8);  // #45E532 : #084B08
        highlight = QColor(16, 124, 16);  // #107C10
        break;
    case 5:
        accentColor = isDarkMode ? QColor(216, 141, 225) : QColor(111, 35, 130);  // #D88DE1 : #6F2382
        highlight = QColor(177, 70, 194);  // #B146C2
        break;
    default:
        accentColor = isDarkMode ? QColor(76, 194, 255) : QColor(0, 62, 146);  // #4CC2FF : #003E92
        highlight = QColor(0, 120, 212);  // #0078D4
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

    const QWindowList &windows = QGuiApplication::topLevelWindows();
    for (QWindow* window : windows) {
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
        QObject::connect(qApp, &QGuiApplication::focusWindowChanged, this, [this](QWindow* window) {
            if (window) {
                HWND hwnd = (HWND)window->winId();
                if (hwnd) {
                    COLORREF color = (m_titlebarColorMode == 0) ? RGB(31, 31, 31) : RGB(230, 230, 230);
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

void GameCore::setCursor(bool customCursor) {
    m_useCustomCursor = customCursor;

    if (!customCursor) {
        QGuiApplication::restoreOverrideCursor();
        return;
    }

    // Create the custom cursor
    QPixmap cursorPixmap(":/cursors/material.png");
    m_customCursor = QCursor(cursorPixmap, 0, 0);

    const QWindowList& windows = QGuiApplication::topLevelWindows();
    for (QWindow* window : windows) {
        applyCustomCursorForWindow(window);
    }
}

void GameCore::resetCursorForWindow(QWindow* window) {
    if (window) {
        window->unsetCursor();
    }
}

void GameCore::applyCustomCursorForWindow(QWindow* window) {
    if (window && m_useCustomCursor) {
        window->setCursor(m_customCursor);
    }
}

bool GameCore::eventFilter(QObject *watched, QEvent *event) {
    if (!m_useCustomCursor) {
        return QObject::eventFilter(watched, event);
    }

    QWindow *window = qobject_cast<QWindow*>(watched);
    if (!window) {
        return QObject::eventFilter(watched, event);
    }

    if (event->type() == QEvent::CursorChange) {
        Qt::CursorShape shape = window->cursor().shape();

        // If it's a resize cursor, let it be (don't override)
        if (shape == Qt::SizeHorCursor ||
            shape == Qt::SizeVerCursor ||
            shape == Qt::SizeFDiagCursor ||
            shape == Qt::SizeBDiagCursor ||
            shape == Qt::SizeAllCursor) {
            return false; // Let the system handle resize cursors
        }

        // For other cursors, apply our custom cursor
        if (shape == Qt::ArrowCursor) {
            applyCustomCursorForWindow(window);
            return true; // We handled it
        }
    } else if (event->type() == QEvent::HoverEnter || event->type() == QEvent::Enter) {
        // Reset to default cursor when leaving a resize handle
        applyCustomCursorForWindow(window);
    }

    return QObject::eventFilter(watched, event);
}

QString GameCore::getLogFilePath() const {
    QString logPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/logs";
    QDir logDir(logPath);
    if (!logDir.exists()) {
        logDir.mkpath(".");
    }

    return logDir.absolutePath();
}

bool GameCore::writeToLogFile(const QString &logMessage) const {
    if (m_currentLogFile.isEmpty()) {
        return false;
    }

    QFile file(m_currentLogFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << logMessage << "\n";
        file.close();
        return true;
    }
    return false;
}

QStringList GameCore::getLogFiles() const {
    QString logPath = getLogFilePath();
    QDir logDir(logPath);
    if (!logDir.exists()) {
        return QStringList();
    }

    // Sort by modified date, newest first
    QStringList files = logDir.entryList(QStringList() << "*.log", QDir::Files, QDir::Time);
    return files;
}

QString GameCore::readLogFile(const QString &filename) const {
    QString logPath = getLogFilePath();
    QFile file(logPath + "/" + filename);

    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString content = stream.readAll();
        file.close();
        return content;
    }

    return QString();
}

void GameCore::cleanupOldLogFiles(int maxFiles) {
    QStringList files = getLogFiles();
    if (files.size() <= maxFiles) {
        return;
    }

    QString logPath = getLogFilePath();

    // Remove oldest log files
    for (int i = maxFiles; i < files.size(); i++) {
        QFile::remove(logPath + "/" + files[i]);
    }
}

int GameCore::getCurrentMonitorAvailableHeight(QWindow* window) const {
    if (!window) {
        const QWindowList& windows = QGuiApplication::topLevelWindows();
        for (QWindow* activeWindow : windows) {
            if (activeWindow->isVisible()) {
                window = activeWindow;
                break;
            }
        }
    }

    if (!window) {
        return QGuiApplication::primaryScreen()->availableGeometry().height();
    }

    QScreen* screen = window->screen();
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }

    return screen->availableGeometry().height();
}

int GameCore::getCurrentMonitorAvailableWidth(QWindow* window) const {
    if (!window) {
        const QWindowList& windows = QGuiApplication::topLevelWindows();
        for (QWindow* activeWindow : windows) {
            if (activeWindow->isVisible()) {
                window = activeWindow;
                break;
            }
        }
    }

    if (!window) {
        return QGuiApplication::primaryScreen()->availableGeometry().width();
    }

    QScreen* screen = window->screen();
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }

    return screen->availableGeometry().width();
}
