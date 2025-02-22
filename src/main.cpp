#include "gamecore.h"
#include "steamintegration.h"
#include "gametimer.h"
#include "gamelogic.h"
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
    GameCore* gameCore = new GameCore();
    GameTimer* gameTimer = new GameTimer();
    GameLogic* gameLogic = new GameLogic();

    SteamIntegrationForeign::s_singletonInstance = steamIntegration;
    GameCoreForeign::s_singletonInstance = gameCore;
    GameTimerForeign::s_singletonInstance = gameTimer;
    GameLogicForeign::s_singletonInstance = gameLogic;

    QQmlApplicationEngine engine;

    gameCore->init();

    engine.loadFromModule("net.odizinne.retr0mine", "Main");

    return app.exec();
}
