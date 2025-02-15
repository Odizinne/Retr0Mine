#ifndef UTILS_H
#define UTILS_H

#include <QString>

namespace Utils {
bool isDarkMode();
QString mapSteamToAppLanguage(QString steamLanguage);
QString mapSystemToAppLanguage(QString systemLanguage);
QString mapIndexToLanguageCode(int index);
}; // namespace Utils

#endif // UTILS_H
