#include "MainWindow.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPalette>
#include <QProcessEnvironment>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QStyleHints>
#include "Utils.h"

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , engine(new QQmlApplicationEngine(this))
    , settings("Odizinne", "Retr0Mine")
    , rootContext(engine->rootContext())
    , translator(new QTranslator(this))
    , m_gameLogic(new MinesweeperLogic(this))
    , isRunningOnGamescope(false)
    , shouldShowWelcomeMessage(false)
{
    QString desktop = QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP");
    isRunningOnGamescope = desktop.toLower() == "gamescope";

    connect(QGuiApplication::styleHints(),
            &QStyleHints::colorSchemeChanged,
            this,
            &MainWindow::onColorSchemeChanged);

    m_steamIntegration = new SteamIntegration(this);
    if (!m_steamIntegration->initialize()) {
        qWarning() << "Failed to initialize Steam integration";
    }

    if (!settings.value("welcomeMessageShown", false).toBool()) resetSettings();

    int colorSchemeIndex = settings.value("colorSchemeIndex").toInt();
    setThemeColorScheme(colorSchemeIndex);

    setupAndLoadQML();
}

MainWindow::~MainWindow()
{
    if (engine) {
        engine->deleteLater();
    }
    if (translator) {
        translator->deleteLater();
    }
}

void MainWindow::onColorSchemeChanged()
{
    if (settings.value("colorSchemeIndex").toInt() == 0) {
        setColorScheme();
    }
}

void MainWindow::resetSettings()
{
    settings.setValue("themeIndex", 0);
    settings.setValue("languageIndex", 0);
    settings.setValue("difficulty", 0);
    settings.setValue("invertLRClick", false);
    settings.setValue("autoreveal", false);
    settings.setValue("enableQuestionMarks", true);
    settings.setValue("loadLastGame", false);
    settings.setValue("soundEffects", true);
    settings.setValue("volume", 1.0);
    settings.setValue("soundPackIndex", 2);
    settings.setValue("animations", true);
    settings.setValue("cellFrame", true);
    settings.setValue("contrastFlag", true);
    settings.setValue("cellSize", 1);
    settings.setValue("customWidth", 8);
    settings.setValue("customHeight", 8);
    settings.setValue("customMines", 10);
    settings.setValue("dimSatisfied", false);
    settings.setValue("startFullScreen", isRunningOnGamescope ? true : false);
    settings.setValue("fixedSeed", -1);
    settings.setValue("displaySeedAtGameOver", false);
    settings.setValue("colorBlindness", 0);
    settings.setValue("flagSkinIndex", 0);

    settings.setValue("welcomeMessageShown", true);
    shouldShowWelcomeMessage = true;
}

void MainWindow::setupAndLoadQML()
{
    int styleIndex = settings.value("themeIndex", 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();

    setQMLStyle(styleIndex);
    setLanguage(languageIndex);
    setColorScheme();

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(m_steamIntegration, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(m_gameLogic, QQmlEngine::CppOwnership);

    engine->setInitialProperties({
        {"mainWindow", QVariant::fromValue(this)},
        {"steamIntegration", QVariant::fromValue(m_steamIntegration)},
        {"gameLogic", QVariant::fromValue(m_gameLogic)}
    });

    engine->load(QUrl("qrc:/qml/Main.qml"));
}

void MainWindow::setQMLStyle(int index)
{
    QString style;
    switch(index) {
    case 0:
        style = "FluentWinUI3";
        break;
    case 1:
        style = "Universal";
        break;
    case 2:
        style = "Fusion";
        break;
    case 3:
        style = "Universal";
        break;
    }

    currentTheme = index;
    QQuickStyle::setStyle(style);
}

void MainWindow::setThemeColorScheme(int colorSchemeIndex)
{
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

    setColorScheme();
#endif
}

void MainWindow::setLanguage(int index)
{
    QString languageCode;

    if (index == 0) {
        if (m_steamIntegration->m_initialized) {
            languageCode = Utils::mapSteamToAppLanguage(m_steamIntegration->getSteamUILanguage());
        } else {
            QLocale locale;
            languageCode = Utils::mapSystemToAppLanguage(locale.name());
        }
    } else {
        languageCode = Utils::mapIndexToLanguageCode(index);
    }

    loadLanguage(languageCode);
    engine->retranslate();

    m_languageIndex = index;
    emit languageIndexChanged();
}

bool MainWindow::loadLanguage(QString languageCode)
{
    qGuiApp->removeTranslator(translator);

    delete translator;
    translator = new QTranslator(this);

    QString filePath = ":/translations/Retr0Mine_" + languageCode + ".qm";

    if (translator->load(filePath)) {
        qGuiApp->installTranslator(translator);
        return true;
    }

    return false;
}

void MainWindow::setColorScheme()
{
    m_isDarkMode = Utils::isDarkMode() || (currentTheme == 1 && isRunningOnGamescope) ||
                   (currentTheme == 0 && isRunningOnGamescope);
    m_accentColor = Utils::getAccentColor();

    emit darkModeChanged();
    emit accentColorChanged();
}

void MainWindow::restartRetr0Mine() const
{
    QProcess::startDetached(QGuiApplication::applicationFilePath(), QGuiApplication::arguments());
    QGuiApplication::quit();
}

QStringList MainWindow::getSaveFiles() const
{
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }
    QStringList files = saveDir.entryList(QStringList() << "*.json", QDir::Files);
    files.removeAll("leaderboard.json");
    return files;
}

bool MainWindow::saveGameState(const QString &data, const QString &filename) const
{
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    QFile file(saveDir.filePath(filename));
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << data;
        file.close();
        return true;
    }
    return false;
}

QString MainWindow::loadGameState(const QString &filename) const
{
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

void MainWindow::deleteSaveFile(const QString &filename)
{
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    QString fullPath = saveDir.filePath(filename);
    QFile::remove(fullPath);
}

QString MainWindow::getLeaderboardPath() const
{
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(savePath).filePath("leaderboard.json");
}

bool MainWindow::saveLeaderboard(const QString &data) const
{
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

QString MainWindow::loadLeaderboard() const
{
    QFile file(getLeaderboardPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString data = stream.readAll();
        file.close();
        return data;
    }
    return QString();
}
