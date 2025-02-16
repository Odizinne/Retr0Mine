#include "MainWindow.h"
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
    MainWindow w;
    return app.exec();
}
