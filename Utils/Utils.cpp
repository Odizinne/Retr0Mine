#include "Utils.h"
#include <QBuffer>
#include <QDebug>
#include <QGuiApplication>
#include <QOperatingSystemVersion>
#include <QPalette>
#include <QProcess>
#include <QSettings>
#include <QStyleHints>

QIcon recolorIcon(QIcon icon, QColor color)
{
    QPixmap pixmap = icon.pixmap(32, 32);
    QImage img = pixmap.toImage();

    for (int y = 0; y < img.height(); ++y) {
        for (int x = 0; x < img.width(); ++x) {
            QColor pixelColor = img.pixelColor(x, y);
            if (pixelColor.alpha() > 0) { // Ignore transparent pixels
                // Preserve alpha and apply new RGB color
                img.setPixelColor(x,
                                  y,
                                  QColor(color.red(),
                                         color.green(),
                                         color.blue(),
                                         pixelColor.alpha()));
            }
        }
    }

    return QIcon(QPixmap::fromImage(img));
}

bool Utils::isDarkMode()
{
    if (qGuiApp->styleHints()->colorScheme() == Qt::ColorScheme::Dark)
        return true;
    else if (qGuiApp->styleHints()->colorScheme() == Qt::ColorScheme::Light)
        return false;
    else {
        QPalette palette = QGuiApplication::palette();
        QColor backgroundColor = palette.color(QPalette::Window);
        return (backgroundColor.lightness() < 128) ? true : false;
    }
}

QString Utils::getAccentColor()
{
    QPalette palette = QGuiApplication::palette();
    QColor highlight = palette.color(QPalette::Highlight);
    return highlight.name();
}

QString Utils::getFlagIcon(QColor accentColor)
{
    QIcon flagIcon = recolorIcon(QIcon(":/icons/flag.png"), accentColor);
    QPixmap flagPixmap = flagIcon.pixmap(32, 32);
    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    buffer.open(QIODevice::WriteOnly);
    flagPixmap.save(&buffer, "PNG");
    return QString("data:image/png;base64,") + byteArray.toBase64();
}

QString Utils::getOperatingSystem()
{
    const QOperatingSystemVersion current = QOperatingSystemVersion::current();

    if (current.type() == QOperatingSystemVersion::Windows) {
        const QOperatingSystemVersionBase &win11 = QOperatingSystemVersion::Windows11;
        const QOperatingSystemVersion &win10 = QOperatingSystemVersion::Windows10;

        if (current >= win11) {
            return "windows11";
        }
        if (current >= win10 && current < win11) {
            return "windows10";
        }
    }

    return "unknown";
}

QString Utils::mapSteamToAppLanguage(QString steamLanguage)
{
    static const QMap<QString, QString> languageMap = {{"english", "en"},
                                                       {"french", "fr"},
                                                       {"german", "de"},
                                                       {"spanish", "es"},
                                                       {"italian", "it"},
                                                       {"japanese", "ja"},
                                                       {"schinese", "zh_CN"},
                                                       {"tchinese", "zh_TW"},
                                                       {"koreana", "ko"},
                                                       {"russian", "ru"}};

    return languageMap.value(steamLanguage.toLower(), "en");
}

QString Utils::mapSystemToAppLanguage(QString systemLanguage)
{
    if (!systemLanguage.startsWith("zh")) {
        systemLanguage = systemLanguage.section('_', 0, 0);
    }

    static const QMap<QString, QString> languageMap = {{"en", "en"},
                                                       {"fr", "fr"},
                                                       {"de", "de"},
                                                       {"es", "es"},
                                                       {"it", "it"},
                                                       {"ja", "ja"},
                                                       {"ko", "ko"},
                                                       {"ru", "ru"},
                                                       {"zh_TW", "zh_TW"},
                                                       {"zh_CN", "zh_CN"}};

    return languageMap.value(systemLanguage, "en");
}

QString Utils::mapIndexToLanguageCode(int index)
{
    static const QMap<int, QString> languageMap = {{1, "en"},
                                                   {2, "fr"},
                                                   {3, "de"},
                                                   {4, "es"},
                                                   {5, "it"},
                                                   {6, "ja"},
                                                   {7, "zh_CN"},
                                                   {8, "zh_TW"},
                                                   {9, "ko"},
                                                   {10, "ru"}};
    return languageMap.value(index, "en");
}
