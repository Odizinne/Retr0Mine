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
#include "MinesweeperLogic.h"
#include "Utils.h"

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , engine(new QQmlApplicationEngine(this))
    , settings("Odizinne", "Retr0Mine")
    , rootContext(engine->rootContext())
    , translator(new QTranslator(this))
    , currentOS(Utils::getOperatingSystem())
    , isRunningOnGamescope(false)
{
    QString desktop = QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP");
    isRunningOnGamescope = desktop.toLower() == "gamescope";

    connect(QGuiApplication::styleHints(),
            &QStyleHints::colorSchemeChanged,
            this,
            &MainWindow::onColorSchemeChanged);

    m_steamIntegration = new SteamIntegration(this);
    if (!m_steamIntegration->initialize()) {
        qWarning() << "Failed to initialize Steam";
    } else {
        qDebug() << "Steam integration enabled";
        rootContext->setContextProperty("steamIntegration", m_steamIntegration);
    }

    setupAndLoadQML();
}

void MainWindow::onColorSchemeChanged()
{
    setColorScheme();
}

void MainWindow::setupAndLoadQML()
{
    int styleIndex = settings.value("themeIndex", isRunningOnGamescope ? 2 : 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();
    int cellSize = settings.value("cellSize", 2).toInt();

    if (styleIndex == 1) {
        setW10Theme();
    } else if (styleIndex == 2) {
        setW11Theme();
    } else if (styleIndex == 3) {
        setFusionTheme();
    } else if (styleIndex == 4) {
        setSteamDeckDarkTheme();
    } else {
        if (currentOS == "windows10")
            setW10Theme();
        else if (currentOS == "windows11")
            setW11Theme();
        else
            setFusionTheme();
    }

    if (cellSize == 0) {
        cellSize = 25;
    } else if (cellSize == 1) {
        cellSize = 35;
    } else if (cellSize == 2) {
        cellSize = isRunningOnGamescope ? 43 : 45;
    } else {
        cellSize = 55;
    }
    setLanguage(languageIndex);
    setColorScheme();

    rootContext->setContextProperty("loadedCellSize", cellSize);
    rootContext->setContextProperty("mainWindow", this);
    qmlRegisterType<MinesweeperLogic>("com.odizinne.minesweeper", 1, 0, "MinesweeperLogic");

    engine->load(QUrl("qrc:/qml/Main.qml"));
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
    rootContext->setContextProperty("languageIndex", index);
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
    QColor accentColor = Utils::getAccentColor();
    bool isSystemDark = Utils::isDarkMode();
    bool darkMode = isSystemDark || currentTheme == 4;

    if (currentTheme == 2 && isRunningOnGamescope)
        darkMode = true;

    rootContext->setContextProperty("gamescope", isRunningOnGamescope);
    rootContext->setContextProperty("flagIcon", Utils::getFlagIcon(accentColor));
    rootContext->setContextProperty("isDarkMode", darkMode);
    rootContext->setContextProperty("accentColor", accentColor);
}

void MainWindow::setW10Theme()
{
    currentTheme = 1;
    QQuickStyle::setStyle("Universal");
    rootContext->setContextProperty("windows10", QVariant(true));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setW11Theme()
{
    currentTheme = 2;
    QQuickStyle::setStyle("FluentWinUI3");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(true));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setFusionTheme()
{
    currentTheme = 3;
    QQuickStyle::setStyle("Fusion");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(true));
}

void MainWindow::setSteamDeckDarkTheme()
{
    currentTheme = 4;
    QQuickStyle::setStyle("Universal");
    rootContext->setContextProperty("windows10", QVariant(true));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(false));
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
