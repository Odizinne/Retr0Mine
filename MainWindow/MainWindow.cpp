#include "MainWindow.h"
#include <QQmlContext>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDesktopServices>
#include <QQuickStyle>
#include <QGuiApplication>
#include "Utils.h"
#include "MinesweeperLogic.h"

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , engine(new QQmlApplicationEngine(this))
    , rootContext(engine->rootContext())
    , isWindows10(Utils::isWindows10())
    , isWindows11(Utils::isWindows11())
    , isLinux(Utils::isLinux())
    , translator(new QTranslator(this))
{
    setupAndLoadQML();
}

void MainWindow::setupAndLoadQML() {
    QColor accentColor;
    bool darkMode;
    int themeIndex = settings.value("themeIndex", 0).toInt();


    if (Utils::getTheme() == "light") {
        darkMode = true;
        if (isWindows10) {
            accentColor = Utils::getAccentColor("normal");
        } else if (isWindows11) {
            accentColor = Utils::getAccentColor("light2");
        } else {
            accentColor = "#0000FF";
        }
    } else {
        darkMode = false;
        if (isWindows10) {
            accentColor = Utils::getAccentColor("normal");
        } else if (isWindows11) {
            accentColor = Utils::getAccentColor("dark2");
        } else {
            accentColor = "#0000FF";
        }
    }

    if (themeIndex == 1) {
        setW10Theme();
    } else if (themeIndex == 2) {
        setW11Theme();
    } else if (themeIndex == 3) {
        setFusionTheme();
    } else {
        if (isWindows10) setW10Theme();
        else if (isWindows11) setW11Theme();
        else setFusionTheme();
    }

    rootContext->setContextProperty("themeIndex", themeIndex);
    rootContext->setContextProperty("mainWindow", this);
    rootContext->setContextProperty("isDarkMode", darkMode);
    rootContext->setContextProperty("accentColor", accentColor);

    QIcon flagIcon = Utils::recolorIcon(QIcon(":/icons/flag.png"), accentColor);
    QPixmap flagPixmap = flagIcon.pixmap(32, 32);
    QString filePath = QDir::temp().filePath("flagIcon.png");
    flagPixmap.save(filePath);

    rootContext->setContextProperty("flagIcon", QUrl::fromLocalFile(filePath));

    int difficulty = settings.value("difficulty", 0).toInt();
    rootContext->setContextProperty("gameDifficulty", difficulty);

    bool invertLRClick = settings.value("invertLRClick", false).toBool();
    rootContext->setContextProperty("invertClick", invertLRClick);

    bool autoreveal = settings.value("autoreveal", false).toBool();
    rootContext->setContextProperty("revealConnectedCell", autoreveal);

    bool enableQuestionMarks = settings.value("enableQuestionMarks", true).toBool();
    rootContext->setContextProperty("questionMarks", enableQuestionMarks);

    bool soundEffects = settings.value("soundEffects", true).toBool();
    rootContext->setContextProperty("soundEffects", soundEffects);

    float volume = settings.value("volume", 1).toFloat();
    rootContext->setContextProperty("volume", volume);

    bool animations = settings.value("animations", true).toBool();
    rootContext->setContextProperty("animations", animations);

    bool contrastFlag = settings.value("contrastFlag", false).toBool();
    rootContext->setContextProperty("contrastFlag", contrastFlag);

    bool showCellFrame = settings.value("cellFrame", true).toBool();
    rootContext->setContextProperty("showCellFrame", showCellFrame);

    int languageIndex = settings.value("languageIndex", 0).toInt();
    rootContext->setContextProperty("languageIndex", languageIndex);

    setLanguage(languageIndex);
    qmlRegisterType<MinesweeperLogic>("com.odizinne.minesweeper", 1, 0, "MinesweeperLogic");

    engine->load(QUrl("qrc:/qml/Main.qml"));
}

void MainWindow::saveDifficulty(int difficulty) {
    settings.setValue("difficulty", difficulty);
}

void MainWindow::saveSoundSettings(bool soundEffects, float volume) {
    settings.setValue("soundEffects", soundEffects);
    settings.setValue("volume", volume);
}

void MainWindow::saveControlsSettings(bool invertLRClick, bool autoreveal, bool enableQuestionMarks) {
    settings.setValue("invertLRClick", invertLRClick);
    settings.setValue("autoreveal", autoreveal);
    settings.setValue("enableQuestionMarks", enableQuestionMarks);
}

void MainWindow::saveVisualSettings(bool animations, bool cellFrame, bool contrastFlag) {
    settings.setValue("animations", animations);
    settings.setValue("cellFrame", cellFrame);
    settings.setValue("contrastFlag", contrastFlag);
}

void MainWindow::saveThemeSettings(int index) {
    settings.setValue("themeIndex", index);
}

void MainWindow::saveLanguageSettings(int index) {
    settings.setValue("languageIndex", index);
}

void MainWindow::setLanguage(int index) {
    QString languageCode;
    if (index == 0) {
        QLocale locale;
        languageCode = locale.name().section('_', 0, 0);

        // Try to load system language, fall back to English if not supported
        if (!loadLanguage(languageCode)) {
            languageCode = "en";
            loadLanguage(languageCode);
        }
    } else if (index == 1) {
        languageCode = "en";
        loadLanguage(languageCode);
    } else if (index == 2) {
        languageCode = "fr";
        loadLanguage(languageCode);
    }

    engine->retranslate();
    rootContext->setContextProperty("languageIndex", index);
}

bool MainWindow::loadLanguage(QString languageCode) {
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

bool MainWindow::saveGameState(const QString &data, const QString &filename) const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

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

QString MainWindow::loadGameState(const QString &filename) const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

    QFile file(QDir(savePath).filePath(filename));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString data = stream.readAll();
        file.close();
        return data;
    }
    return QString();
}

QStringList MainWindow::getSaveFiles() const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    return saveDir.entryList(QStringList() << "*.json", QDir::Files);
}

void MainWindow::openSaveFolder() const {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);

    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    QDesktopServices::openUrl(QUrl::fromLocalFile(savePath));
}

void MainWindow::setW10Theme() {
    QQuickStyle::setStyle("Universal");
    rootContext->setContextProperty("windows10", QVariant(true));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setW11Theme() {
    QQuickStyle::setStyle("FluentWinUI3");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(true));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setFusionTheme() {
    QQuickStyle::setStyle("Fusion");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(true));
}

void MainWindow::restartRetr0Mine() const {
    Utils::restartApp();
}
