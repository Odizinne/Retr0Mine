#include "mainwindow.h"
#include "steamintegration.h"
#include "gametimer.h"
#include "minesweeperlogic.h"
#include <QGuiApplication>
#include <QIcon>
#include <QLoggingCategory>

int main(int argc, char *argv[])
{
    QLoggingCategory::setFilterRules("qt.multimedia.ffmpeg=false");
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Odizinne");
    app.setApplicationName("Retr0Mine");
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));

    SteamIntegration* steamIntegration = new SteamIntegration();
    MainWindow* mainWindow = new MainWindow();
    GameTimer* gameTimer = new GameTimer();
    MinesweeperLogic* minesweeperLogic = new MinesweeperLogic();

    SteamIntegrationForeign::s_singletonInstance = steamIntegration;
    MainWindowForeign::s_singletonInstance = mainWindow;
    GameTimerForeign::s_singletonInstance = gameTimer;
    MinesweeperLogicForeign::s_singletonInstance = minesweeperLogic;

    QQmlApplicationEngine engine;

    mainWindow->init();

    engine.loadFromModule("Retr0Mine", "Main");

    return app.exec();
}
