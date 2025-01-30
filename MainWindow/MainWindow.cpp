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
    int cellSize = settings.value("cellSize", isRunningOnGamescope ? 2 : 1).toInt();

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

    rootContext->setContextProperty("currentOS", currentOS);
    rootContext->setContextProperty("loadedCellSize", cellSize);
    rootContext->setContextProperty("mainWindow", this);
    qmlRegisterType<MinesweeperLogic>("com.odizinne.minesweeper", 1, 0, "MinesweeperLogic");

    engine->load(QUrl("qrc:/qml/Main.qml"));
}

QString MainWindow::mapSteamToAppLanguage(const QString &steamLanguage)
{
    QMap<QString, QString> languageMap = {
        {"english", "en"},
        {"french", "fr"},
        {"german", "de"},
        {"spanish", "es"},
        {"italian", "it"},
        {"japanese", "ja"},
        {"schinese", "zh_CN"},
        {"tchinese", "zh_TW"},
        {"koreana", "ko"},
        {"russian", "ru"}
    };

    return languageMap.value(steamLanguage.toLower(), "en");
}

void MainWindow::setLanguage(int index)
{
    QString languageCode;

    if (index == 0) {
        if (m_steamIntegration->m_initialized) {
            QString steamLang = m_steamIntegration->getSteamUILanguage();
            languageCode = mapSteamToAppLanguage(steamLang);
            loadLanguage(languageCode);

        } else {
            QLocale locale;
            QString fullLocale = locale.name();

            if (fullLocale.startsWith("zh")) {
                languageCode = fullLocale;
            } else {
                languageCode = locale.name().section('_', 0, 0);
            }

            if (!loadLanguage(languageCode)) {
                languageCode = "en";
                loadLanguage(languageCode);
            }
        }

    } else {
        switch (index) {
        case 1:
            languageCode = "en";
            break;
        case 2:
            languageCode = "fr";
            break;
        case 3:
            languageCode = "de";
            break;
        case 4:
            languageCode = "es";
            break;
        case 5:
            languageCode = "it";
            break;
        case 6:
            languageCode = "ja";
            break;
        case 7:
            languageCode = "zh_CN";
            break;
        case 8:
            languageCode = "zh_TW";
            break;
        case 9:
            languageCode = "ko";
            break;
        case 10:
            languageCode = "ru";
            break;
        default:
            languageCode = "en";
            break;
        }
        loadLanguage(languageCode);
    }
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

void MainWindow::deleteSaveFile(const QString &filename)
{
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    QString fullPath = saveDir.filePath(filename);
    QFile::remove(fullPath);
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
    Utils::restartApp();
}

void MainWindow::setColorScheme()
{
    QColor accentColor;
    bool isSystemDark = Utils::isDarkMode();

    switch (currentTheme) {
    case 1:
        accentColor = Utils::getAccentColor("normal");
        break;
    case 2:
        accentColor = Utils::getAccentColor(isSystemDark ? "light2" : "dark1");
        break;
    case 3:
        accentColor = QGuiApplication::palette().color(QPalette::Highlight);
        break;
    default:
        accentColor = QGuiApplication::palette().color(QPalette::Highlight);
        break;
    }

    bool darkMode = isSystemDark || currentTheme == 4;

    QString desktop = QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP");

    if (currentTheme == 2 && isRunningOnGamescope) {
        darkMode = true;
    }

    rootContext->setContextProperty("gamescope", isRunningOnGamescope);
    rootContext->setContextProperty("flagIcon", Utils::getFlagIcon(accentColor));
    rootContext->setContextProperty("isDarkMode", darkMode);
    rootContext->setContextProperty("accentColor", accentColor);
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
