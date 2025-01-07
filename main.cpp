#include <QGuiApplication>
#include <QIcon>
#include "MainWindow.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));
    MainWindow w;
    return app.exec();
}
