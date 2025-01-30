#ifndef UTILS_H
#define UTILS_H

#include <QColor>
#include <QIcon>
#include <QString>

namespace Utils {
bool isDarkMode();
QString getAccentColor();
QString getOperatingSystem();
QString getFlagIcon(QColor accentColor);
QString mapSteamToAppLanguage(QString steamLanguage);
QString mapSystemToAppLanguage(QString systemLanguage);
QString mapIndexToLanguageCode(int index);
}; // namespace Utils

#endif // UTILS_H
