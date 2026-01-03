import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root
    
    property string audioName: ""
    property string selectedFilePath: ""
    property string selectedImagePath: ""
    property string errorMessage: ""
    
    signal audioAdded(string name, string filePath, string imagePath)
    signal cancelled()
    
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
    
    // Set audio file from external source (drag and drop)
    function setAudioFile(filePath) {
        selectedFilePath = filePath
        filePathText.text = filePath.toString().split('/').pop()
        // Auto-fill name from filename if empty
        if (audioName === "") {
            audioName = extractNameFromPath(filePath)
        }
    }
    
    // Connect to audio manager error signal
    Connections {
        target: audioManager
        function onError(message) {
            errorMessage = message
            errorTimer.restart()
        }
    }
    
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: errorMessage = ""
    }
    
    // Extract filename without extension
    function extractNameFromPath(path) {
        var filename = path.toString().split('/').pop()
        // Remove file extension
        var lastDot = filename.lastIndexOf('.')
        if (lastDot > 0) {
            filename = filename.substring(0, lastDot)
        }
        // Replace underscores and hyphens with spaces
        filename = filename.replace(/_/g, ' ').replace(/-/g, ' ')
        return filename
    }
    
    FileDialog {
        id: fileDialog
        title: "Select Audio File"
        nameFilters: ["Audio files (*.mp3 *.wav *.ogg *.flac *.m4a)", "All files (*)"]
        onAccepted: {
            selectedFilePath = fileDialog.selectedFile
            filePathText.text = selectedFilePath.toString().split('/').pop()
            // Auto-fill name from filename if empty
            if (audioName === "") {
                audioName = extractNameFromPath(selectedFilePath)
            }
        }
    }
    
    FileDialog {
        id: imageDialog
        title: "Select Cover Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp *.webp)", "All files (*)"]
        onAccepted: {
            selectedImagePath = imageDialog.selectedFile
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        
        // Error message
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 6
            color: "#DC2626"
            visible: errorMessage !== ""
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                
                Text {
                    text: "⚠"
                    font.pixelSize: 16
                    color: "white"
                }
                
                Text {
                    text: errorMessage
                    font.pixelSize: 11
                    color: "white"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                Text {
                    text: "✕"
                    font.pixelSize: 14
                    color: "white"
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: errorMessage = ""
                    }
                }
            }
        }
        
        // Name Audio File
        Text {
            text: "Name Audio File"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            
            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.margins: 12
                color: "white"
                font.pixelSize: 13
                text: audioName
                onTextChanged: audioName = text
                
                Text {
                    anchors.fill: parent
                    text: "Enter Name Here..."
                    color: "#6B7280"
                    font.pixelSize: 13
                    visible: parent.text.length === 0
                }
            }
        }
        
        // Assign to Slot
        Text {
            text: "Assign to Slot"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                
                Text {
                    text: "Select Available Slot"
                    font.pixelSize: 13
                    color: "#6B7280"
                    Layout.fillWidth: true
                }
                
                Text {
                    text: "▼"
                    font.pixelSize: 10
                    color: "#6B7280"
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }
        
        // Cover Image section
        Text {
            text: "Cover Image (Optional)"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 8
            color: "#1a1a2e"
            border.color: selectedImagePath ? "#7C3AED" : "#2a2a3e"
            clip: true
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12
                
                // Image preview
                Rectangle {
                    width: 64
                    height: 64
                    radius: 6
                    color: "#2a2a3e"
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        source: selectedImagePath
                        fillMode: Image.PreserveAspectCrop
                        visible: selectedImagePath !== ""
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🖼"
                        font.pixelSize: 24
                        color: "#6B7280"
                        visible: selectedImagePath === ""
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: selectedImagePath ? selectedImagePath.toString().split('/').pop() : "No image selected"
                        font.pixelSize: 11
                        color: selectedImagePath ? "white" : "#6B7280"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: "Click to browse"
                        font.pixelSize: 10
                        color: "#7C3AED"
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: imageDialog.open()
            }
        }
        
        // Upload audio area
        Text {
            text: "Audio File"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            id: audioDropZone
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 8
            color: audioDropArea.containsDrag ? "#2a2a4e" : "transparent"
            border.color: audioDropArea.containsDrag ? "#7C3AED" : (selectedFilePath ? "#7C3AED" : "#4B5563")
            border.width: audioDropArea.containsDrag ? 2 : 1
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: audioDropArea.containsDrag ? "↓" : (selectedFilePath ? "✓" : "⬆")
                    font.pixelSize: 20
                    color: audioDropArea.containsDrag ? "#7C3AED" : (selectedFilePath ? "#7C3AED" : "#6B7280")
                }
                
                Text {
                    id: filePathText
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: audioDropZone.width - 20
                    text: audioDropArea.containsDrag ? "Drop audio file here" : (selectedFilePath ? selectedFilePath.toString().split('/').pop() : "Click or drag audio here")
                    font.pixelSize: 11
                    color: audioDropArea.containsDrag ? "#7C3AED" : (selectedFilePath ? "#7C3AED" : "#6B7280")
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            
            DropArea {
                id: audioDropArea
                anchors.fill: parent
                
                onEntered: function(drag) {
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
                                setAudioFile(url)
                                break
                            }
                        }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fileDialog.open()
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 12
            
            Rectangle {
                Layout.preferredWidth: 80
                height: 36
                radius: 6
                color: "transparent"
                border.color: "#4B5563"
                
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 13
                    color: "#9CA3AF"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        audioName = ""
                        selectedFilePath = ""
                        selectedImagePath = ""
                        errorMessage = ""
                        cancelled()
                    }
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 80
                height: 36
                radius: 6
                color: selectedFilePath ? "#7C3AED" : "#4B5563"
                
                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 13
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: selectedFilePath
                    onClicked: {
                        if (selectedFilePath) {
                            // Clear any previous error
                            errorMessage = ""
                            // Use extracted name if user didn't provide one
                            var finalName = audioName ? audioName : extractNameFromPath(selectedFilePath)
                            audioAdded(finalName, selectedFilePath, selectedImagePath)
                            // Only clear fields if no error occurred (checked by parent)
                            if (errorMessage === "") {
                                audioName = ""
                                selectedFilePath = ""
                                selectedImagePath = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
