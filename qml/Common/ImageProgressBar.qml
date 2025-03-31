// Copyright (C) 2017 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only
import QtQuick
import QtQuick.Templates as T
import Odizinne.Retr0Mine

T.ProgressBar {
    id: control
    implicitWidth: 200
    implicitHeight: 50

    contentItem: Item {
        anchors.fill: parent

        Image {
            id: baseImage
            anchors.fill: parent
            source: Constants.retr0mineLogo
            sourceSize.width: control.width
            sourceSize.height: control.height
            antialiasing: true
            mipmap: true
            opacity: 0.3
        }

        Item {
            width: parent.width * control.position
            height: parent.height
            clip: true

            Image {
                width: control.width
                height: control.height
                source: Constants.retr0mineLogo
                sourceSize.width: control.width
                sourceSize.height: control.height
                antialiasing: true
                mipmap: true
                opacity: 1.0
            }
        }
    }

    background: Item {
        implicitWidth: 200
        implicitHeight: 50
    }
}
