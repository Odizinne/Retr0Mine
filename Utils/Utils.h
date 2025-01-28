#ifndef UTILS_H
#define UTILS_H

#include <QColor>
#include <QIcon>
#include <QString>

namespace Utils {
bool isDarkMode();
QString getAccentColor(const QString &accentKey);
bool isWindows10();
bool isWindows11();
bool isLinux();
void restartApp();
QString getOperatingSystem();
QString getFlagIcon(QColor accentColor);
}; // namespace Utils

#endif // UTILS_H
