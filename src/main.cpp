#include "gamecore.h"
#include "steamintegration.h"
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

    SteamIntegrationForeign::s_singletonInstance = steamIntegration;
    GameCoreForeign::s_singletonInstance = gameCore;

    QQmlApplicationEngine engine;

    gameCore->init();

    engine.loadFromModule("net.odizinne.retr0mine", "Main");

    return app.exec();
}
