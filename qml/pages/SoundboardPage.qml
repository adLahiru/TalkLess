import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property int selectedSlots: 0
    property int rightPanelIndex: 0  // 0: Details, 1: Add Audio, 2: Meters, 3: Teleprompter
    property var selectedClip: null
    
    // Current soundboard name from the view
    property string currentSoundboardName: soundboardView.currentSection ? soundboardView.currentSection.name : "Soundboard"
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Main Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: parent.width * 0.7
            spacing: 0
            
            // Page Header with background
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                color: "transparent"
                clip: true
                
                // Background Image
                Image {
                    anchors.fill: parent
                    source: "qrc:/TalkLess/resources/images/background-52.png"
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
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    
                    ColumnLayout {
                        spacing: 8
                        
                        Text {
                            text: currentSoundboardName
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            color: "white"
                        }
                        
                        Text {
                            text: "Manage and trigger your audio clips"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Menu button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 6
                        color: Qt.rgba(255, 255, 255, 0.1)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "⋮"
                            font.pixelSize: 16
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    // Get Started button
                    Rectangle {
                        width: 120
                        height: 40
                        radius: 8
                        color: "#7C3AED"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Get Started"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rightPanelIndex = 1
                        }
                    }
                }
            }
            
            // Filter toolbar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "transparent"
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    // Filter icons
                    Repeater {
                        model: ["▶", "🌐", "✏", "🗑"]
                        
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: "#1a1a2e"
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 14
                                color: "white"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
            
            // Audio Grid
            ScrollView {
                id: audioGridScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                // Helper function to check if file is audio
                function isAudioFile(filePath) {
                    var path = filePath.toString().toLowerCase()
                    var audioExtensions = [".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac", ".wma", ".aiff"]
                    for (var i = 0; i < audioExtensions.length; i++) {
                        if (path.endsWith(audioExtensions[i])) {
                            return true
                        }
                    }
                    return false
                }
                
                // Helper function to extract name from path
                function extractNameFromPath(path) {
                    var filename = path.toString().split('/').pop()
                    var lastDot = filename.lastIndexOf('.')
                    if (lastDot > 0) {
                        filename = filename.substring(0, lastDot)
                    }
                    filename = filename.replace(/_/g, ' ').replace(/-/g, ' ')
                    return filename
                }
                
                // Global drop area for the entire grid
                DropArea {
                    id: gridDropArea
                    anchors.fill: parent
                    z: -1  // Behind the grid items
                    
                    onEntered: function(drag) {
                        if (drag.hasUrls) {
                            var hasAudio = false
                            for (var i = 0; i < drag.urls.length; i++) {
                                if (audioGridScrollView.isAudioFile(drag.urls[i].toString())) {
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
                                if (audioGridScrollView.isAudioFile(url)) {
                                    var filename = audioGridScrollView.extractNameFromPath(url)
                                    var sectionId = soundboardView.currentSection ? soundboardView.currentSection.id : ""
                                    var clip = audioManager.addClip(filename, url, "", sectionId)
                                    if (clip) {
                                        selectedClip = clip
                                        rightPanelIndex = 0
                                    }
                                    break // Only handle first audio file
                                }
                            }
                        }
                    }
                }
                
                // Visual feedback overlay when dragging
                Rectangle {
                    anchors.fill: parent
                    color: "#7C3AED"
                    opacity: gridDropArea.containsDrag ? 0.1 : 0
                    visible: gridDropArea.containsDrag
                    z: 100
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200
                        height: 100
                        radius: 12
                        color: "#1a1a2e"
                        border.color: "#7C3AED"
                        border.width: 2
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "↓"
                                font.pixelSize: 32
                                color: "#7C3AED"
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Drop Audio Here"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "#7C3AED"
                            }
                        }
                    }
                }
                
                GridLayout {
                    width: parent.width
                    columns: 4
                    columnSpacing: 16
                    rowSpacing: 16
                    
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    
                    // Add Audio Card
                    AddAudioCard {
                        onClicked: rightPanelIndex = 1
                        onAudioDropped: function(filePath) {
                            // Extract name from file path
                            var filename = filePath.toString().split('/').pop()
                            var lastDot = filename.lastIndexOf('.')
                            if (lastDot > 0) {
                                filename = filename.substring(0, lastDot)
                            }
                            filename = filename.replace(/_/g, ' ').replace(/-/g, ' ')
                            
                            var sectionId = soundboardView.currentSection ? soundboardView.currentSection.id : ""
                            var clip = audioManager.addClip(filename, filePath, "", sectionId)
                            if (clip) {
                                selectedClip = clip
                                rightPanelIndex = 0
                            }
                        }
                    }
                    
                    // Audio Cards
                    Repeater {
                        model: soundboardView.currentSectionClips
                        
                        AudioCard {
                            required property var modelData
                            required property int index
                            
                            title: modelData ? modelData.title : ""
                            hotkey: modelData ? modelData.hotkey : ""
                            tagLabel: modelData && modelData.tagLabel ? modelData.tagLabel : ""
                            tagColor: modelData && modelData.tagColor ? modelData.tagColor : "#EAB308"
                            isSelected: selectedClip && selectedClip.id === modelData.id
                            isPlaying: modelData ? modelData.isPlaying : false
                            audioClipId: modelData ? modelData.id : ""
                            imagePath: modelData ? modelData.imagePath : ""
                            
                            onClicked: {
                                selectedClip = modelData
                                rightPanelIndex = 0
                            }
                            onPlayClicked: {
                                if (modelData) {
                                    audioManager.playClip(modelData.id)
                                }
                            }
                            onStopClicked: {
                                if (modelData) {
                                    audioManager.stopClip(modelData.id)
                                }
                            }
                            onDeleteClicked: {
                                if (modelData) {
                                    audioManager.removeClip(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
            
            // Selection bar (when slots selected)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: selectedSlots > 0 ? 50 : 0
                color: "#1a1a2e"
                visible: selectedSlots > 0
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    
                    Text {
                        text: selectedSlots + " Slots Selected"
                        font.pixelSize: 13
                        color: "white"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 80
                        height: 32
                        radius: 6
                        color: "#EF4444"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: 12
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    Rectangle {
                        width: 140
                        height: 32
                        radius: 6
                        color: "#2a2a3e"
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "Move to Soundboard"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                            }
                            
                            Text {
                                text: "▼"
                                font.pixelSize: 8
                                color: "#9CA3AF"
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
            
            // Bottom Audio Player
            AudioPlayer {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 16
                title: "Greetings"
                subtitle: "Press F1 to play"
            }
        }
        
        // Right Panel
        StackLayout {
            Layout.preferredWidth: parent.width * 0.22
            Layout.maximumWidth: 320
            Layout.minimumWidth: 240
            Layout.fillHeight: true
            currentIndex: rightPanelIndex
            
            AudioDetailsPanel {
                clip: selectedClip
            }
            
            AddAudioPanel {
                onAudioAdded: function(name, filePath, imagePath) {
                    var sectionId = soundboardView.currentSection ? soundboardView.currentSection.id : ""
                    var clip = audioManager.addClip(name, filePath, "", sectionId)
                    if (clip) {
                        if (imagePath) {
                            clip.imagePath = imagePath
                        }
                        selectedClip = clip
                        rightPanelIndex = 0
                    } else {
                        // Duplicate detected, stay on add panel to show error
                        console.log("Failed to add clip - duplicate detected")
                    }
                }
                onCancelled: {
                    rightPanelIndex = 0
                }
            }
            
            MetersPanel {}
            
            TeleprompterPanel {}
        }
    }
}
