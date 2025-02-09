import QtQuick.Controls.Universal

ApplicationWindow {
    Universal.theme: root.isGamescope && settings.themeIndex === 3 ? Universal.Dark : Universal.System
    Universal.accent: mainWindow.accentColor
}
