// DropdownSelector.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string placeholder: "Select..."
    property string selectedValue: ""
    property string icon: ""
    property var model: []
    
    signal itemSelected(string value)
    
    height: 50
    color: "#2A2A2A"
    radius: 12
    border.width: 1
    border.color: "#3A3A3A"

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Icon
        Text {
            text: root.icon
            font.pixelSize: 18
            visible: root.icon.length > 0
        }

        Text {
            text: root.selectedValue.length > 0 ? root.selectedValue : root.placeholder
            color: root.selectedValue.length > 0 ? "#FFFFFF" : "#AAAAAA"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
            Layout.fillWidth: true
        }

        // Dropdown arrow
        Text {
            text: "▼"
            color: "#666666"
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("Dropdown clicked:", root.placeholder)
        }
    }
}
