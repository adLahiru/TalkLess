import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string title: "System Settings"
    property string subtitle: "Manage subscription plans, quotas, and billing details."
    property string backgroundImage: ""
    
    height: 180
    color: "transparent"
    clip: true
    
    // Background Image
    Image {
        id: bgImage
        anchors.fill: parent
        source: backgroundImage
        fillMode: Image.PreserveAspectCrop
        opacity: 0.8
    }
    
    // Gradient Overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#1a0a2e" }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: "#2a1040" }
        }
    }
    
    // Content
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        Text {
            text: title
            font.pixelSize: 32
            font.weight: Font.Bold
            color: "white"
        }
        
        Text {
            text: subtitle
            font.pixelSize: 14
            color: "#9CA3AF"
        }
    }
}
