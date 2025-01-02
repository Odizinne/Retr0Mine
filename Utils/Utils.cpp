#include "Utils.h"
#include <QDebug>
#include <QSettings>

#ifdef _WIN32
#include <Windows.h>
#else
#include <QGuiApplication>
#include <QPalette>
#endif

QString Utils::getTheme()
{
#ifdef _WIN32
    // Determine the theme based on registry value
    QSettings settings(
        "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        QSettings::NativeFormat);
    int value = settings.value("AppsUseLightTheme", 1).toInt();

    return (value == 0) ? "light" : "dark";
#else
    QPalette palette = QGuiApplication::palette();
    QColor backgroundColor = palette.color(QPalette::Window);

    bool isDark = backgroundColor.lightness() < 128;
    QString theme;
    if (isDark) {
        theme = "light";
    } else {
        theme = "dark";
    }

    return theme;
#endif
}

#ifdef _WIN32
QString toHex(BYTE value)
{
    const char* hexDigits = "0123456789ABCDEF";
    return QString("%1%2")
        .arg(hexDigits[value >> 4])
        .arg(hexDigits[value & 0xF]);
}
#endif

QString Utils::getAccentColor(const QString &accentKey)
{
#ifdef _WIN32
    HKEY hKey;
    BYTE accentPalette[32];  // AccentPalette contains 32 bytes
    DWORD bufferSize = sizeof(accentPalette);

    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Accent", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        if (RegGetValueW(hKey, NULL, L"AccentPalette", RRF_RT_REG_BINARY, NULL, accentPalette, &bufferSize) == ERROR_SUCCESS) {
            RegCloseKey(hKey);

            int index = 0;
            if (accentKey == "light3") index = 0;
            else if (accentKey == "light2") index = 4;
            else if (accentKey == "light1") index = 8;
            else if (accentKey == "normal") index = 12;
            else if (accentKey == "dark1") index = 16;
            else if (accentKey == "dark2") index = 20;
            else if (accentKey == "dark3") index = 24;
            else {
                qDebug() << "Invalid accentKey provided.";
                return "#FFFFFF";
            }

            QString red = toHex(accentPalette[index]);
            QString green = toHex(accentPalette[index + 1]);
            QString blue = toHex(accentPalette[index + 2]);

            return QString("#%1%2%3").arg(red, green, blue);
        } else {
            qDebug() << "Failed to retrieve AccentPalette from the registry.";
        }

        RegCloseKey(hKey);
    } else {
        qDebug() << "Failed to open registry key.";
    }

    return "#FFFFFF";
#else
    return "#0000FF";
#endif
}

QIcon Utils::recolorIcon(QIcon icon, QColor color) {
    QPixmap pixmap = icon.pixmap(32, 32);
    QImage img = pixmap.toImage();

    for (int y = 0; y < img.height(); ++y) {
        for (int x = 0; x < img.width(); ++x) {
            QColor pixelColor = img.pixelColor(x, y);
            if (pixelColor.alpha() > 0) {  // Ignore transparent pixels
                // Preserve alpha and apply new RGB color
                img.setPixelColor(x, y, QColor(color.red(), color.green(), color.blue(), pixelColor.alpha()));
            }
        }
    }

    return QIcon(QPixmap::fromImage(img));
}

#ifdef _WIN32
int getBuildNumber()
{
    QSettings registry("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", QSettings::NativeFormat);
    QVariant buildVariant = registry.value("CurrentBuild");

    if (!buildVariant.isValid()) {
        buildVariant = registry.value("CurrentBuildNumber");
    }

    if (buildVariant.isValid() && buildVariant.canConvert<QString>()) {
        bool ok;
        int buildNumber = buildVariant.toString().toInt(&ok);
        if (ok) {
            return buildNumber;
        }
    }

    qDebug() << "Failed to retrieve build number from the registry.";
    return -1;
}
#endif

bool Utils::isWindows10()
{
#ifdef _WIN32
    int buildNumber = getBuildNumber();
    return (buildNumber >= 10240 && buildNumber < 22000);
#else
    return false;
#endif
}

bool Utils::isWindows11() {
#ifdef _WIN32
    int buildNumber = getBuildNumber();
    return (buildNumber >= 22000);
#else
    return false;
#endif
}

bool Utils::isLinux() {
#ifdef __linux__
    return true;
#else
    return false;
#endif
}
