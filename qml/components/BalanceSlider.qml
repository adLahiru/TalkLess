// BalanceSlider.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property string leftLabel: "0% mic"
    property string rightLabel: "100% soundboard"
    property real value: 0.5  // 0.0 (left) to 1.0 (right)
    
    signal balanceChanged(real newValue)
    
    implicitHeight: 50  // Compact height

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Slider container
    Item {
        anchors.fill: parent

        // Main track - light purple/gray background with rounded edges
        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 10
            height: 17
            radius: 8.5
            color: "#E8E0F0"  // Light purple/gray

            // Left dot
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#9999AA"
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }

            // Right dot
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#9999AA"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Purple vertical slider handle
        Rectangle {
            id: handle
            width: 4
            height: 44
            radius: 2
            color: "#6B4C9A"  // Purple color
            x: track.x + 11 + (root.value * (track.width - 22))
            anchors.verticalCenter: track.verticalCenter

            // Gray cover/outline around the handle
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 4
                height: parent.height + 4
                radius: 4
                color: "transparent"
                border.width: 2
                border.color: "#AAAAAA"
                z: -1
            }
        }

        // Interaction area
        MouseArea {
            anchors.fill: parent
            
            onPressed: (mouse) => updateValue(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed) updateValue(mouse.x)
            }
            
            function updateValue(mouseX) {
                var trackStart = 11
                var trackEnd = track.width - 11
                var ratio = (mouseX - trackStart) / (trackEnd - trackStart)
                ratio = Math.max(0, Math.min(1, ratio))
                root.value = ratio
                root.balanceChanged(ratio)
            }
        }

        // Left label - directly below track
        Text {
            anchors.left: track.left
            anchors.top: track.bottom
            anchors.topMargin: 2
            text: root.leftLabel
            color: "#999999"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 12
        }

        // Right label - directly below track
        Text {
            anchors.right: track.right
            anchors.top: track.bottom
            anchors.topMargin: 2
            text: root.rightLabel
            color: "#999999"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 12
        }
    }
}
