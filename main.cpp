#include <QGuiApplication>
#include <MainWindow.h>
#include <QQuickStyle>
#include <Utils.h>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    if (Utils::isWindows10()) {
        QQuickStyle::setStyle("Universal");
    }

    if (Utils::isWindows11()) {
        QQuickStyle::setStyle("FluentWinUI3");
    }

    if (Utils::isLinux()) {
        QQuickStyle::setStyle("Fusion");
    }

    MainWindow w;

    return app.exec();
}
