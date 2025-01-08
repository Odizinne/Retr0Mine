#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QTranslator>

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
    Q_INVOKABLE void saveLanguageSettings(int index);
    Q_INVOKABLE void setLanguage(int index);
    Q_INVOKABLE void saveColorSchemeSettings(int index);
    Q_INVOKABLE void setColorScheme(int index);
    Q_INVOKABLE void saveCellSizeSettings(int index);
    Q_INVOKABLE void deleteSaveFile(const QString &filename);

    Q_INVOKABLE bool saveGameState(const QString &data, const QString &filename) const;
    Q_INVOKABLE QString loadGameState(const QString &filename) const;
    Q_INVOKABLE QStringList getSaveFiles() const;
    Q_INVOKABLE void openSaveFolder() const;
    Q_INVOKABLE void restartRetr0Mine() const;

private slots:
    void onColorSchemeChanged(Qt::ColorScheme scheme);

private:
    QSettings settings;
    QQmlApplicationEngine* engine;
    QQmlContext* rootContext;
    QTranslator* translator;
    bool isWindows10;
    bool isWindows11;
    bool isLinux;

    void setupAndLoadQML();
    void setW10Theme();
    void setW11Theme();
    void setFusionTheme();
    bool loadLanguage(QString languageCode);
    int currentTheme;
};

#endif // MAINWINDOW_H
