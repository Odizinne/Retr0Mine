import QtQuick.Controls.Universal

ApplicationWindow {
    Universal.theme: root.isGamescope && settings.themeIndex === 1 ? Universal.Dark : Universal.System
    Universal.accent: mainWindow.accentColor
}
