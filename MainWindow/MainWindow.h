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
    Q_INVOKABLE void saveControlsSettings(bool invertLRClick, bool autoreveal, bool enableQuestionMarks);
    Q_INVOKABLE void saveVisualSettings(bool animations, bool cellFrame);

    Q_INVOKABLE QString getWindowsPath() const;
    Q_INVOKABLE QString getLinuxPath() const;
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename) const;
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void openSaveFolder() const;

private:
    QSettings settings;
    QQmlApplicationEngine* engine;
    bool isWindows10;
    bool isWindows11;
    bool isLinux;
};

#endif // MAINWINDOW_H
