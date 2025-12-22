import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string title: "Greeting"
    property string hotkey: "Alt+F2+Shift"
    property string imagePath: ""
    property string tagLabel: "Morning"
    property color tagColor: "#EAB308"
    property bool isSelected: false
    property bool isPlaying: false
    property bool showTag: true
    property string audioClipId: ""
    
    signal clicked()
    signal playClicked()
    signal menuClicked()
    signal deleteClicked()
    
    width: 160
    height: 120
    radius: 12
    color: "#1a1a2e"
    border.color: isSelected ? "#7C3AED" : "transparent"
    border.width: isSelected ? 2 : 0
    clip: true
    
    // Background Image
    Image {
        anchors.fill: parent
        source: imagePath
        fillMode: Image.PreserveAspectCrop
        opacity: 0.8
    }
    
    // Gradient Overlay
    Rectangle {
        anchors.fill: parent
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.6) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.9) }
        }
    }
    
    // Tag Label (Morning, etc)
    Rectangle {
        visible: showTag && tagLabel !== ""
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        height: 22
        width: tagText.width + 16
        radius: 4
        color: tagColor
        
        Text {
            id: tagText
            anchors.centerIn: parent
            text: tagLabel
            font.pixelSize: 11
            font.weight: Font.Medium
            color: tagColor === "#EAB308" ? "#000000" : "white"
        }
    }
    
    // Bottom Content
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 4
        
        // Title
        Text {
            text: title
            font.pixelSize: 13
            font.weight: Font.Medium
            color: "white"
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: title !== ""
        }
        
        // Bottom row with hotkey and controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            
            // Play/Pause icon
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: isPlaying ? "⏸" : "▶"
                    font.pixelSize: 10
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playClicked()
                        if (root.audioClipId) {
                            if (isPlaying) {
                                audioManager.pauseClip(root.audioClipId)
                            } else {
                                audioManager.playClip(root.audioClipId)
                            }
                        }
                    }
                }
            }
            
            // Hotkey
            Text {
                text: hotkey
                font.pixelSize: 10
                color: "#9CA3AF"
                Layout.fillWidth: true
            }
            
            // Menu icon
            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "🗑"
                    font.pixelSize: 12
                    color: "#EF4444"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menuClicked()
                        deleteClicked()
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        z: -1
    }
}
