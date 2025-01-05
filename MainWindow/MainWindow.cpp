#include "MainWindow.h"
#include <QQmlContext>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDesktopServices>
#include "Utils.h"
#include "MinesweeperLogic.h"

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , engine(new QQmlApplicationEngine)
    , isWindows10(Utils::isWindows10())
    , isWindows11(Utils::isWindows11())
    , isLinux(Utils::isLinux())
{
    QColor accentColor;
    bool darkMode;
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

    engine->rootContext()->setContextProperty("windows10", isWindows10);
    engine->rootContext()->setContextProperty("windows11", isWindows11);
    engine->rootContext()->setContextProperty("linux", isLinux);
    engine->rootContext()->setContextProperty("mainWindow", this);
    engine->rootContext()->setContextProperty("isDarkMode", darkMode);
    engine->rootContext()->setContextProperty("accentColor", accentColor);

    QIcon flagIcon = Utils::recolorIcon(QIcon(":/icons/flag.png"), accentColor);
    QPixmap flagPixmap = flagIcon.pixmap(32, 32);
    QString filePath = QDir::temp().filePath("flagIcon.png");
    flagPixmap.save(filePath);

    engine->rootContext()->setContextProperty("flagIcon", QUrl::fromLocalFile(filePath));

    int difficulty = settings.value("difficulty", 0).toInt();
    engine->rootContext()->setContextProperty("gameDifficulty", difficulty);

    bool invertLRClick = settings.value("invertLRClick", false).toBool();
    engine->rootContext()->setContextProperty("invertClick", invertLRClick);

    bool autoreveal = settings.value("autoreveal", false).toBool();
    engine->rootContext()->setContextProperty("revealConnectedCell", autoreveal);

    bool enableQuestionMarks = settings.value("enableQuestionMarks", true).toBool();
    engine->rootContext()->setContextProperty("enableQuestionMarks", enableQuestionMarks);

    bool soundEffects = settings.value("soundEffects", true).toBool();
    engine->rootContext()->setContextProperty("soundEffects", soundEffects);

    bool volume = settings.value("volume", 1).toFloat();
    engine->rootContext()->setContextProperty("volume", volume);

    bool animations = settings.value("animations", true).toBool();
    engine->rootContext()->setContextProperty("animations", animations);

    bool showCellFrame = settings.value("cellFrame", true).toBool();
    engine->rootContext()->setContextProperty("showCellFrame", showCellFrame);

    qmlRegisterType<MinesweeperLogic>("com.odizinne.minesweeper", 1, 0, "MinesweeperLogic");

    QString uiFile = "qrc:/qml/Main.qml";
    engine->load(QUrl(uiFile));
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

void MainWindow::saveVisualSettings(bool animations, bool cellFrame) {
    settings.setValue("animations", animations);
    settings.setValue("cellFrame", cellFrame);
}

QString MainWindow::getWindowsPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

QString MainWindow::getLinuxPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
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

    // Create the directory if it doesn't exist
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    // Open the folder in the system's file browser
    QDesktopServices::openUrl(QUrl::fromLocalFile(savePath));
}
