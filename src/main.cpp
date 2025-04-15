#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QLoggingCategory>
#include <QQuickWindow>
#include "gamecore.h"
#include "steamintegration.h"

int main(int argc, char *argv[]) {
    QLoggingCategory::setFilterRules("qt.multimedia.*=false");
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Odizinne");
    app.setApplicationName("Retr0Mine");
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));

    QQuickWindow* dummyWindow = new QQuickWindow();
    /*==========================================
    | Creating this dummy window seems         |
    | to trick steam overlay notification      |
    | and prevent it from displaying in        |
    | settings window which cause flickers     |
    | This is only an issue when using OpenGL  |
    ==========================================*/

    SteamIntegration* steamIntegration = new SteamIntegration(&app);
    GameCore* gameCore = new GameCore(&app);
    SteamIntegrationForeign::s_singletonInstance = steamIntegration;
    GameCoreForeign::s_singletonInstance = gameCore;

    QQmlApplicationEngine engine;
    gameCore->init();
    QString renderingBackend = gameCore->getRenderingBackend();
    qputenv("QSG_RHI_BACKEND", renderingBackend.toUtf8());

    engine.loadFromModule("Odizinne.Retr0Mine", "Main");

    delete dummyWindow;

    return app.exec();
}
