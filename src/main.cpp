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

    SteamIntegration* steamIntegration = new SteamIntegration(&app);
    GameCore* gameCore = new GameCore(&app);
    GameTimer* gameTimer = new GameTimer(&app);
    GameLogic* gameLogic = new GameLogic(&app);

    SteamIntegrationForeign::s_singletonInstance = steamIntegration;
    GameCoreForeign::s_singletonInstance = gameCore;
    GameTimerForeign::s_singletonInstance = gameTimer;
    GameLogicForeign::s_singletonInstance = gameLogic;

    QTimer *steamCallbackTimer = new QTimer();
    QObject::connect(steamCallbackTimer, &QTimer::timeout, []() {
        if (SteamIntegrationForeign::s_singletonInstance) {
            SteamIntegrationForeign::s_singletonInstance->runCallbacks();
        }
    });
    steamCallbackTimer->start(100);

    QQmlApplicationEngine engine;

    gameCore->init();

    engine.loadFromModule("net.odizinne.retr0mine", "Main");

    return app.exec();
}
