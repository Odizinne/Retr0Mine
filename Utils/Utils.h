#ifndef UTILS_H
#define UTILS_H

#include <QString>
#include <QIcon>
#include <QColor>

namespace Utils
{
QString getTheme();
QString getAccentColor(const QString &accentKey);
QIcon recolorIcon(QIcon icon, QColor color);
bool isWindows10();
bool isWindows11();
bool isLinux();
void restartApp();
};

#endif // UTILS_H
