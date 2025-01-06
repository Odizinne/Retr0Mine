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
    Q_INVOKABLE void saveSoundSettings(bool soundEffects, float volume);
    Q_INVOKABLE void saveControlsSettings(bool invertLRClick, bool autoreveal, bool enableQuestionMarks);
    Q_INVOKABLE void saveVisualSettings(bool animations, bool cellFrame, bool contrastFlag);
    Q_INVOKABLE void saveThemeSettings(int index);
    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename) const;
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void openSaveFolder() const;

    Q_INVOKABLE void restartRetr0Mine() const;

private:
    QSettings settings;
    QQmlApplicationEngine* engine;
    bool isWindows10;
    bool isWindows11;
    bool isLinux;
    void setW10Theme();
    void setW11Theme();
    void setFusionTheme();
};

#endif // MAINWINDOW_H
