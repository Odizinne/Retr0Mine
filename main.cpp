#include <QGuiApplication>
#include <MainWindow.h>
#include <QIcon>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));
    MainWindow w;

    return app.exec();
}
