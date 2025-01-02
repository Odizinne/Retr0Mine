#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>

class MainWindow : public QObject
{
    Q_OBJECT
public:
    explicit MainWindow(QObject *parent = nullptr);

    Q_INVOKABLE void saveDifficulty(int difficulty);
    Q_INVOKABLE void saveSoundSettings(bool soundEffects);
    Q_INVOKABLE void saveControlsSettings(bool invertLRClick);

private:
    QSettings settings;
    QQmlApplicationEngine* engine;
    bool isWindows10;
    bool isWindows11;
    bool isLinux;
};

#endif // MAINWINDOW_H
