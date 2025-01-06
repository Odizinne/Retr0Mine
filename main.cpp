#include <QGuiApplication>
#include <MainWindow.h>
#include <QIcon>
#include <QLocale>
#include <QTranslator>
#include <QDir>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setWindowIcon(QIcon(":/icons/icon.png"));

    QLocale locale;
    QString languageCode = locale.name().section('_', 0, 0);
    QTranslator translator;
    if (translator.load(":/translations/Retr0Mine_" + languageCode + ".qm")) {
        app.installTranslator(&translator);
        qDebug() << "installed";
    }

    QDir dir(":/translations");
    qDebug() << "Resource directory exists:" << dir.exists();
    qDebug() << "Resource directory contents:" << dir.entryList();
    MainWindow w;

    return app.exec();
}
