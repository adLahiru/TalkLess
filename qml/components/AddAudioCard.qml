import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    signal clicked()
    signal audioDropped(string filePath)
    
    width: 160
    height: 120
    radius: 12
    color: dropArea.containsDrag ? "#2a2a4e" : "#1a1a2e"
    border.color: dropArea.containsDrag ? "#7C3AED" : "#3a3a4e"
    border.width: dropArea.containsDrag ? 2 : 1
    
    // Supported audio file extensions
    readonly property var audioExtensions: [".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac", ".wma", ".aiff"]
    
    function isAudioFile(filePath) {
        var path = filePath.toString().toLowerCase()
        for (var i = 0; i < audioExtensions.length; i++) {
            if (path.endsWith(audioExtensions[i])) {
                return true
            }
        }
        return false
    }
    
    function extractLocalPath(url) {
        var path = url.toString()
        // Remove file:// prefix if present
        if (path.startsWith("file://")) {
            path = path.substring(7)
        }
        // Handle encoded spaces and special characters
        path = decodeURIComponent(path)
        return path
    }
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 40
            height: 40
            radius: 8
            color: "transparent"
            border.color: dropArea.containsDrag ? "#7C3AED" : "#4B5563"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: dropArea.containsDrag ? "↓" : "+"
                font.pixelSize: 24
                font.weight: Font.Light
                color: dropArea.containsDrag ? "#7C3AED" : "#9CA3AF"
            }
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: dropArea.containsDrag ? "Drop Audio Here" : "Add Audio"
            font.pixelSize: 13
            color: dropArea.containsDrag ? "#7C3AED" : "#9CA3AF"
        }
    }
    
    DropArea {
        id: dropArea
        anchors.fill: parent
        
        onEntered: function(drag) {
            // Check if any of the dropped files are audio files
            if (drag.hasUrls) {
                var hasAudio = false
                for (var i = 0; i < drag.urls.length; i++) {
                    if (isAudioFile(drag.urls[i].toString())) {
                        hasAudio = true
                        break
                    }
                }
                drag.accepted = hasAudio
            } else {
                drag.accepted = false
            }
        }
        
        onDropped: function(drop) {
            if (drop.hasUrls) {
                for (var i = 0; i < drop.urls.length; i++) {
                    var url = drop.urls[i].toString()
                    if (isAudioFile(url)) {
                        // Emit signal with the file path
                        root.audioDropped(url)
                        break // Only handle first audio file
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        propagateComposedEvents: true
        
        onClicked: root.clicked()
        
        onEntered: {
            if (!dropArea.containsDrag) {
                root.border.color = "#7C3AED"
            }
        }
        
        onExited: {
            if (!dropArea.containsDrag) {
                root.border.color = "#3a3a4e"
            }
        }
    }
}


