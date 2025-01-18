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

    QQmlApplicationEngine* engine;

    Q_INVOKABLE void setLanguage(int index);
    Q_INVOKABLE void setColorScheme(int index);
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
    QQmlContext* rootContext;
    QTranslator* translator;
    QString currentOS;

    void setupAndLoadQML();
    void setW10Theme();
    void setW11Theme();
    void setFusionTheme();
    bool loadLanguage(QString languageCode);
    int currentTheme;
};

#endif // MAINWINDOW_H
