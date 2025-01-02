#include <QGuiApplication>
#include <MainWindow.h>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    MainWindow w;

    return app.exec();
}
