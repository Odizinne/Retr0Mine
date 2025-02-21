#include "mainwindow.h"
#include <QGuiApplication>
#include <QIcon>
#include <QLoggingCategory>

// main.cpp
int main(int argc, char *argv[])
{
    QLoggingCategory::setFilterRules("qt.multimedia.ffmpeg=false");
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Odizinne");
    app.setApplicationName("Retr0Mine");
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));

    // Create MainWindow and register as singleton
    MainWindow* mainWindow = new MainWindow();
    MainWindowForeign::s_singletonInstance = mainWindow;

    // Create engine
    QQmlApplicationEngine engine;

    // Do initial setup using MainWindow
    if (!mainWindow->settings.value("welcomeMessageShown", false).toBool()) {
        mainWindow->resetSettings();
    }

    int colorSchemeIndex = mainWindow->settings.value("colorSchemeIndex").toInt();
    int styleIndex = mainWindow->settings.value("themeIndex", 0).toInt();
    int languageIndex = mainWindow->settings.value("languageIndex", 0).toInt();

    mainWindow->setThemeColorScheme(colorSchemeIndex);
    mainWindow->setQMLStyle(styleIndex);
    mainWindow->setLanguage(languageIndex);

    // Set up QML properties
    QQmlEngine::setObjectOwnership(mainWindow->m_steamIntegration, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(mainWindow->m_gameLogic, QQmlEngine::CppOwnership);

    engine.setInitialProperties({
        {"steamIntegration", QVariant::fromValue(mainWindow->m_steamIntegration)},
        {"gameLogic", QVariant::fromValue(mainWindow->m_gameLogic)},
        {"gameTimer", QVariant::fromValue(mainWindow->m_gameTimer)}
    });

    // Load QML
    engine.loadFromModule("Retr0Mine", "Main");

    return app.exec();
}
