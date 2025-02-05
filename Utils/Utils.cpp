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

QString Utils::mapSteamToAppLanguage(QString steamLanguage)
{
    static const QMap<QString, QString> languageMap = {{"english", "en"},
                                                       {"french", "fr"}};
    return languageMap.value(steamLanguage.toLower(), "en");
}

QString Utils::mapSystemToAppLanguage(QString systemLanguage)
{
    static const QMap<QString, QString> languageMap = {{"en", "en"},
                                                       {"fr", "fr"}};
    return languageMap.value(systemLanguage, "en");
}

QString Utils::mapIndexToLanguageCode(int index)
{
    static const QMap<int, QString> languageMap = {{1, "en"},
                                                   {2, "fr"}};
    return languageMap.value(index, "en");
}
