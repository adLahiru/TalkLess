// ActionButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Rectangle {
    id: root
    
    property string text: "Button"
    property string icon: ""
    property color backgroundColor: Colors.surface
    property color hoverColor: Colors.surfaceLight
    property color textColor: Colors.textPrimary
    
    signal clicked()
    
    height: 50
    color: mouseArea.containsMouse ? root.hoverColor : root.backgroundColor
    radius: 12
    border.width: 1
    border.color: Colors.border

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: root.icon
            font.pixelSize: 18
            visible: root.icon.length > 0
        }

        Text {
            text: root.text
            color: root.textColor
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
}
