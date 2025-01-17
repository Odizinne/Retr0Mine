#include "MainWindow.h"
#include "Utils.h"
#include "MinesweeperLogic.h"
#include <QQmlContext>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDesktopServices>
#include <QQuickStyle>
#include <QGuiApplication>
#include <QStyleHints>
#include <QBuffer>
#include <QPalette>

MainWindow::MainWindow(QObject *parent)
    : QObject{parent}
    , settings("Odizinne", "Retr0Mine")
    , engine(new QQmlApplicationEngine(this))
    , rootContext(engine->rootContext())
    , translator(new QTranslator(this))
    , isWindows10(Utils::isWindows10())
    , isWindows11(Utils::isWindows11())
    , isLinux(Utils::isLinux())
{
    setupAndLoadQML();
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
            this, &MainWindow::onColorSchemeChanged);
}

void MainWindow::onColorSchemeChanged(Qt::ColorScheme scheme)
{
    if (settings.value("colorScheme").toInt() != 0) return;

    if (scheme == Qt::ColorScheme::Light) {
        setColorScheme(1);
    } else if (scheme == Qt::ColorScheme::Dark) {
        setColorScheme(2);
    }
}

void MainWindow::setupAndLoadQML() {
    int styleIndex = settings.value("themeIndex", 0).toInt();
    int colorSchemeIndex = settings.value("colorScheme", 0).toInt();
    int languageIndex = settings.value("languageIndex", 0).toInt();
    int cellSize = settings.value("cellSize", 1).toInt();

    if (styleIndex == 1) {
        setW10Theme();
    } else if (styleIndex == 2) {
        setW11Theme();
    } else if (styleIndex == 3) {
        setFusionTheme();
    } else {
        if (isWindows10) setW10Theme();
        else if (isWindows11) setW11Theme();
        else setFusionTheme();
    }
    setColorScheme(colorSchemeIndex);

    if (cellSize == 0) {
        cellSize = 25;
    } else if (cellSize ==1) {
        cellSize = 35;
    } else if (cellSize ==2) {
        cellSize = 45;
    } else {
        cellSize = 55;
    }
    setLanguage(languageIndex);

    rootContext->setContextProperty("loadedCellSize", cellSize);
    rootContext->setContextProperty("mainWindow", this);
    qmlRegisterType<MinesweeperLogic>("com.odizinne.minesweeper", 1, 0, "MinesweeperLogic");

    engine->load(QUrl("qrc:/qml/Main.qml"));
}

void MainWindow::setLanguage(int index) {
    QString languageCode;
    if (index == 0) {
        QLocale locale;
        QString fullLocale = locale.name();

        // Check if the locale is Chinese
        if (fullLocale.startsWith("zh")) {
            languageCode = fullLocale; // Use full code for Chinese
        } else {
            languageCode = locale.name().section('_', 0, 0);
        }

        // Try to load system language, fall back to English if not supported
        if (!loadLanguage(languageCode)) {
            languageCode = "en";
            loadLanguage(languageCode);
        }
    } else {
        // Map index to language codes
        switch (index) {
        case 1:  // English
            languageCode = "en";
            break;
        case 2:  // French
            languageCode = "fr";
            break;
        case 3:  // German
            languageCode = "de";
            break;
        case 4:  // Spanish
            languageCode = "es";
            break;
        case 5:  // Italian
            languageCode = "it";
            break;
        case 6:  // Japanese
            languageCode = "ja";
            break;
        case 7:  // Chinese Simplified
            languageCode = "zh_CN";
            break;
        case 8:  // Chinese Traditional
            languageCode = "zh_TW";
            break;
        case 9:  // Korean
            languageCode = "ko";
            break;
        case 10: // Russian
            languageCode = "ru";
            break;
        default:
            languageCode = "en";  // Fallback to English
            break;
        }
        loadLanguage(languageCode);
    }
    engine->retranslate();
    rootContext->setContextProperty("languageIndex", index);
}

bool MainWindow::loadLanguage(QString languageCode) {
    qGuiApp->removeTranslator(translator);

    delete translator;
    translator = new QTranslator(this);

    QString filePath = ":/translations/Retr0Mine_" + languageCode + ".qm";

    if (translator->load(filePath)) {
        qGuiApp->installTranslator(translator);
        return true;
    }

    return false;
}

bool MainWindow::saveGameState(const QString &data, const QString &filename) const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    QFile file(saveDir.filePath(filename));
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << data;
        file.close();
        return true;
    }
    return false;
}

QString MainWindow::loadGameState(const QString &filename) const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

    QFile file(QDir(savePath).filePath(filename));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString data = stream.readAll();
        file.close();
        return data;
    }
    return QString();
}

QStringList MainWindow::getSaveFiles() const {
    QString savePath = QStandardPaths::writableLocation(
        QStandardPaths::AppDataLocation
        );

    QDir saveDir(savePath);
    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    return saveDir.entryList(QStringList() << "*.json", QDir::Files);
}

void MainWindow::openSaveFolder() const {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);

    if (!saveDir.exists()) {
        saveDir.mkpath(".");
    }

    QDesktopServices::openUrl(QUrl::fromLocalFile(savePath));
}

void MainWindow::deleteSaveFile(const QString &filename) {
    QString savePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir saveDir(savePath);
    QString fullPath = saveDir.filePath(filename);
    QFile::remove(fullPath);
}

void MainWindow::setW10Theme() {
    currentTheme = 1;
    QQuickStyle::setStyle("Universal");
    rootContext->setContextProperty("windows10", QVariant(true));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setW11Theme() {
    currentTheme = 2;
    QQuickStyle::setStyle("FluentWinUI3");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(true));
    rootContext->setContextProperty("fusion", QVariant(false));
}

void MainWindow::setFusionTheme() {
    currentTheme = 3;
    QQuickStyle::setStyle("Fusion");
    rootContext->setContextProperty("windows10", QVariant(false));
    rootContext->setContextProperty("windows11", QVariant(false));
    rootContext->setContextProperty("fusion", QVariant(true));
}

void MainWindow::restartRetr0Mine() const {
    Utils::restartApp();
}

void MainWindow::setColorScheme(int index) {
    QColor accentColor;
    bool darkMode;

    if (index == 1) {
        //light
        darkMode = false;
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Light);
        if (currentTheme == 1) {
            accentColor = Utils::getAccentColor("normal");
        } else if (currentTheme == 2) {
            accentColor = Utils::getAccentColor("dark2");
        } else {
            accentColor = QGuiApplication::palette().color(QPalette::Highlight);
        }
    } else if (index == 2) {
        //dark
        QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
        darkMode = true;
        if (currentTheme == 1) {
            accentColor = Utils::getAccentColor("normal");
        } else if (currentTheme == 2) {
            accentColor = Utils::getAccentColor("light2");
        } else {
            accentColor = QGuiApplication::palette().color(QPalette::Highlight);
        }
    } else {
        // 0 = System
        QGuiApplication::styleHints()->unsetColorScheme();
        if (Utils::getTheme() == "light") {
            darkMode = true;
            if (currentTheme == 1) {
                accentColor = Utils::getAccentColor("normal");
            } else if (currentTheme == 2) {
                accentColor = Utils::getAccentColor("light2");
            } else {
                accentColor = QGuiApplication::palette().color(QPalette::Highlight);
            }
        } else {
            darkMode = false;
            if (currentTheme == 1) {
                accentColor = Utils::getAccentColor("normal");
            } else if (currentTheme == 2) {
                accentColor = Utils::getAccentColor("dark2");
            } else {
                accentColor = QGuiApplication::palette().color(QPalette::Highlight);
            }
        }
    }

    QIcon flagIcon = Utils::recolorIcon(QIcon(":/icons/flag.png"), accentColor);
    QPixmap flagPixmap = flagIcon.pixmap(32, 32);
    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    buffer.open(QIODevice::WriteOnly);
    flagPixmap.save(&buffer, "PNG");
    QString dataUrl = QString("data:image/png;base64,") + byteArray.toBase64();

    rootContext->setContextProperty("flagIcon", dataUrl);
    rootContext->setContextProperty("appTheme", index);
    rootContext->setContextProperty("isDarkMode", darkMode);
    rootContext->setContextProperty("accentColor", accentColor);
}
