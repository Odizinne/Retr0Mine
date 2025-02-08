#include "Utils.h"
#include <QGuiApplication>
#include <QPalette>
#include <QStyleHints>

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
