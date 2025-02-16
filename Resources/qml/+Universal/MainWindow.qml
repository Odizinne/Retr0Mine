import QtQuick
import QtQuick.Controls.Universal

ApplicationWindow {
    id: appWindow
    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }
    Universal.theme: root.isGamescope && settings.themeIndex === 1 ? Universal.Dark : Universal.System
    Universal.accent: sysPalette.highlight
}
