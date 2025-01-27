#include "Utils.h"
#include <QDebug>
#include <QSettings>
#include <QProcess>
#include <QGuiApplication>
#include <QPalette>
#include <QStyleHints>
#include <QOperatingSystemVersion>
#include <QBuffer>

#ifdef _WIN32
#include <Windows.h>
#endif

QIcon recolorIcon(QIcon icon, QColor color) {
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

void Utils::restartApp()
{
    QProcess::startDetached(QGuiApplication::applicationFilePath(), QGuiApplication::arguments());
    QGuiApplication::quit();
}

bool Utils::isDarkMode()
{
    //Qt::ColorScheme colorScheme = QGuiApplication::styleHints()->colorScheme();
//
    //switch (colorScheme) {
    //case Qt::ColorScheme::Dark:
    //    return true;
    //case Qt::ColorScheme::Light:
    //    return false;
    //default:
        // Fallback in case Qt::ColorScheme::Unknown
        QPalette palette = QGuiApplication::palette();
        QColor backgroundColor = palette.color(QPalette::Window);
        return (backgroundColor.lightness() < 128) ? true : false;
    //}
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
    Q_UNUSED(accentKey);
    QPalette palette = QGuiApplication::palette();
    QColor highlight = palette.color(QPalette::Highlight);
    return highlight.name();
#endif
}

QString Utils::getFlagIcon(QColor accentColor) {
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
        const QOperatingSystemVersionBase& win11 = QOperatingSystemVersion::Windows11;
        const QOperatingSystemVersion& win10 = QOperatingSystemVersion::Windows10;

        if (current >= win11) {
            return "windows11";
        }
        if (current >= win10 && current < win11) {
            return "windows10";
        }
    }

    return "unknown";
}

bool Utils::isGamescope() {
    return QProcessEnvironment::systemEnvironment().value("XDG_CURRENT_DESKTOP") == "gamescope";
}
