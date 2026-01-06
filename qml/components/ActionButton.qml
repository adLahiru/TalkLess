// ActionButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string text: "Button"
    property string icon: ""
    property color backgroundColor: "#2A2A2A"
    property color hoverColor: "#3A3A3A"
    property color textColor: "#FFFFFF"
    
    signal clicked()
    
    height: 50
    color: mouseArea.containsMouse ? root.hoverColor : root.backgroundColor
    radius: 12
    border.width: 1
    border.color: "#3A3A3A"

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
