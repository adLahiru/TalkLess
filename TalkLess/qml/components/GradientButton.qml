// GradientButton.qml
// Reusable gradient button component
pragma ComponentBehavior: Bound

import QtQuick
import "../styles"

Rectangle {
    id: root
    
    property string text: "Button"
    property color gradientStart: Colors.accent  // Default accent
    property color gradientEnd: Colors.secondary    // Default secondary
    property bool isGradient: true
    property color flatColor: Colors.surface
    property color textColor: Colors.textOnPrimary
    property color borderColor: Colors.border
    property bool hasBorder: false
    
    signal clicked()
    
    width: 80
    height: 40
    radius: 8
    color: isGradient ? "transparent" : flatColor
    border.width: hasBorder ? 1 : 0
    border.color: borderColor

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Gradient background (only when isGradient is true)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.isGradient
        layer.enabled: true
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.gradientStart }
            GradientStop { position: 1.0; color: root.gradientEnd }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
