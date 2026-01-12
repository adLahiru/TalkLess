// VolumeMeterSlider.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles"

Item {
    id: root
    
    property real value: 0.45  // 0.0 to 1.0
    property real dbValue: -15  // dB value to display
    
    implicitHeight: 55

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    Item {
        anchors.fill: parent

        // Track background (gray/light)
        Rectangle {
            id: trackBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            radius: 9
            color: Colors.surfaceLight  // Light gray/purple background
        }

        // Green gradient fill (active portion)
        Rectangle {
            id: greenFill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: trackBg.width * root.value
            height: 18
            radius: 9
            
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.success }  // Light green
                GradientStop { position: 1.0; color: Qt.darker(Colors.success, 1.4) }  // Dark green
            }
        }

        // Purple/Blue gradient circle indicator with dB value
        Rectangle {
            id: circleIndicator
            width: 50
            height: 50
            radius: 25
            x: trackBg.width * root.value - width/2
            anchors.verticalCenter: parent.verticalCenter

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Colors.gradientPrimaryStart }  // Blue
                GradientStop { position: 1.0; color: Colors.gradientPrimaryEnd }  // Purple/Magenta
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(root.dbValue) + "db"
                color: Colors.textOnPrimary
                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        // Interaction area for sliding
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            
            onPressed: (mouse) => updateValue(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed) updateValue(mouse.x)
            }
            
            function updateValue(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / trackBg.width))
                root.value = ratio
                // Convert ratio to dB (0 to 1 maps to -60 to 0 dB)
                root.dbValue = -60 + (ratio * 60)
            }
        }
    }
}
