// Copyright (C) 2017 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only
import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Universal

T.ProgressBar {
    id: control
    implicitWidth: 100
    implicitHeight: 100
    property int progressThickness: 3

    contentItem: Item {
        anchors.fill: parent

        Rectangle {
            id: progressBackground
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: control.progressThickness
            border.color: control.Universal.baseLowColor
        }

        Canvas {
            id: progressCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                var centerX = width / 2
                var centerY = height / 2
                var radius = Math.min(width, height) / 2 - (control.progressThickness / 2)
                var startAngle = -Math.PI / 2
                var endAngle = startAngle + (2 * Math.PI * control.position)

                ctx.reset()
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                ctx.lineWidth = control.progressThickness
                ctx.strokeStyle = control.Universal.accent
                ctx.stroke()
            }

            Connections {
                target: control
                function onPositionChanged() {
                    progressCanvas.requestPaint()
                }
            }
        }
    }

    background: Item {
        implicitWidth: 100
        implicitHeight: 100
    }
}
