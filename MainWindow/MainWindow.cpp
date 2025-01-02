#include "MainWindow.h"
#include <QQmlContext>
#include <QDir>
#include "Utils.h"

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , engine(new QQmlApplicationEngine)
{
    QColor accentColor;
    bool darkMode;
    if (Utils::getTheme() == "light") {
        darkMode = true;
        accentColor = Utils::getAccentColor("normal");
    } else {
        darkMode = false;
        accentColor = Utils::getAccentColor("normal");
    }
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

    bool soundEffects = settings.value("soundEffects", true).toBool();
    engine->rootContext()->setContextProperty("soundEffects", soundEffects);

    QString uiFile = "qrc:/qml/Main.qml";
    engine->load(QUrl(uiFile));
}

void MainWindow::saveDifficulty(int difficulty) {
    settings.setValue("difficulty", difficulty);
}

void MainWindow::saveSoundSettings(bool soundEffects) {
    settings.setValue("soundEffects", soundEffects);
}
