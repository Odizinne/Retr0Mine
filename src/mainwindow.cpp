#include "mainwindow.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcessEnvironment>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QStyleHints>

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

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , translator(new QTranslator(this))
    , m_gameLogic(new MinesweeperLogic(this))
    , m_gameTimer(new GameTimer(this))
    , isRunningOnGamescope(false)
    , shouldShowWelcomeMessage(false)
{
    QString desktop = QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP");
    isRunningOnGamescope = desktop.toLower() == "gamescope";
    m_steamIntegration = new SteamIntegration(this);
    m_steamEnabled = m_steamIntegration->initialize();
}

MainWindow::~MainWindow()
{
    if (translator) {
        translator->deleteLater();
    }
}

void MainWindow::init()
{
    if (!settings.value("welcomeMessageShown", false).toBool()) {
        resetSettings();
    }

    int colorSchemeIndex = settings.value("colorSchemeIndex").toInt();
    int styleIndex = settings.value("themeIndex", 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();

    setThemeColorScheme(colorSchemeIndex);
    setQMLStyle(styleIndex);
    setLanguage(languageIndex);
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
#endif
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
    settings.setValue("colorBlindness", 0);
    settings.setValue("flagSkinIndex", 0);
    settings.setValue("fontIndex", 0);

    settings.setValue("welcomeMessageShown", true);
    shouldShowWelcomeMessage = true;
}

void MainWindow::setQMLStyle(int index)
{
    QString style;
    m_isFluent = false;
    m_isUniversal = false;
    m_isFusion = false;

    switch(index) {
    case 0:
        style = "FluentWinUI3";
        m_isFluent = true;
        break;
    case 1:
        style = "Universal";
        m_isUniversal = true;
        break;
    case 2:
        style = "Fusion";
        m_isFusion = true;
        break;
    default:
        style = "FluentWinUI3";
        m_isFluent = true;
        break;
    }

    currentTheme = index;
    QQuickStyle::setStyle(style);

    emit fluentChanged();
    emit universalChanged();
    emit fusionChanged();
}

void MainWindow::setLanguage(int index)
{
    QString languageCode;
    if (index == 0) {
        if (m_steamIntegration->m_initialized) {
            languageCode = getSteamLanguageMap().value(m_steamIntegration->getSteamUILanguage().toLower(), "en");
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
        if (MainWindowForeign::s_engine) {
            static_cast<QQmlEngine*>(MainWindowForeign::s_engine)->retranslate();
        }
    }
    m_languageIndex = index;
    emit languageIndexChanged();
}

bool MainWindow::loadLanguage(QString languageCode)
{
    if (qApp) {
        qApp->removeTranslator(translator);
    }

    delete translator;
    translator = new QTranslator(this);

    QString filePath = ":/translations/retr0mine_" + languageCode + ".qm";

    if (translator->load(filePath)) {
        if (qApp) {
            qApp->installTranslator(translator);
        }
        return true;
    }

    return false;
}

void MainWindow::restartRetr0Mine(int index)
{
    settings.setValue("themeIndex", index);

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
