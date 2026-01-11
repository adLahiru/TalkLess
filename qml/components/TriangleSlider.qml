// TriangleSlider.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property string label: "Mic Level:"
    property real from: -60
    property real to: 0
    property real value: -16
    property string unit: "dB"
    property string description: ""
    
    // Gradient colors
    property color gradientStart: "#3B82F6"
    property color gradientEnd: "#D214FD"
    
    signal sliderMoved(real newValue)
    
    implicitHeight: 60  // Compact height for the slider
    
    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Slider container
    Item {
        anchors.fill: parent

        // Gradient line (thick bar) - vertically centered
        Rectangle {
            id: gradientBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.gradientStart }
                GradientStop { position: 1.0; color: root.gradientEnd }
            }
        }

        // Inverted triangle handle with value above
        Item {
            id: triangleHandle
            width: 30
            height: 28  // Reduced height for tighter spacing
            x: ((root.value - root.from) / (root.to - root.from)) * (parent.width - 14) - 8
            y: gradientBar.y - height  // Position so triangle tip touches top edge of line

            // Value text above triangle (at the base)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: triangleCanvas.top
                anchors.bottomMargin: 2  // Small gap between text and triangle
                text: Math.round(root.value) + root.unit
                color: "#FFFFFF"
                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            // Small equilateral triangle (white)
            Canvas {
                id: triangleCanvas
                width: 14
                height: 12
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    
                    var size = 14  // Equilateral triangle side length
                    var h = size * Math.sqrt(3) / 2  // Height of equilateral triangle
                    var centerX = width / 2
                    
                    // Draw equilateral triangle pointing down
                    ctx.beginPath()
                    ctx.moveTo(centerX - size/2, 0)  // Top left
                    ctx.lineTo(centerX + size/2, 0)  // Top right
                    ctx.lineTo(centerX, h)           // Bottom center (tip)
                    ctx.closePath()
                    
                    // Fill with white
                    ctx.fillStyle = "#FFFFFF"
                    ctx.fill()
                }
            }
        }

        // Invisible slider for interaction
        MouseArea {
            anchors.fill: parent
            
            onPressed: (mouse) => updateValue(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed) updateValue(mouse.x)
            }
            
            function updateValue(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / width))
                root.value = root.from + ratio * (root.to - root.from)
                root.sliderMoved(root.value)
            }
        }

        // Left label (-60dB)
        Text {
            anchors.left: parent.left
            anchors.top: gradientBar.bottom
            anchors.topMargin: 4
            text: Math.round(root.from) + root.unit
            color: "#666666"
            font.pixelSize: 11
        }

        // Right label (0dB)
        Text {
            anchors.right: parent.right
            anchors.top: gradientBar.bottom
            anchors.topMargin: 4
            text: Math.round(root.to) + root.unit
            color: "#666666"
            font.pixelSize: 11
        }
    }
}
