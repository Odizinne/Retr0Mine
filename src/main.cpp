#include <QGuiApplication>
#include <QIcon>
#include "gamecore.h"
#include "steamintegration.h"

int main(int argc, char *argv[]) {
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

    QString renderingBackend = gameCore->getRenderingBackend();
    qputenv("QSG_RHI_BACKEND", renderingBackend.toUtf8());
    engine.loadFromModule("net.odizinne.retr0mine", "Main");

    return app.exec();
}
