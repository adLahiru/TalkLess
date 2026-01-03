import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property string audioName: ""
    property string recordedFilePath: ""
    property string selectedInputDevice: ""
    property bool isRecording: false
    property real recordingTime: 0
    property real trimStart: 0
    property real trimEnd: 100
    
    signal audioAdded(string name, string filePath, string imagePath)
    signal cancelled()
    
    // Timer for recording duration - updates from AudioManager
    Timer {
        id: recordingTimer
        interval: 100
        repeat: true
        running: root.isRecording
        onTriggered: {
            if (typeof audioManager !== "undefined") {
                root.recordingTime = audioManager.getRecordingDuration()
            } else {
                root.recordingTime += 0.1
            }
        }
    }
    
    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    function resetRecording() {
        isRecording = false
        recordingTime = 0
        recordedFilePath = ""
        trimStart = 0
        trimEnd = 100
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        
        // Input Source
        Text {
            text: "Input Source"
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
                    text: selectedInputDevice ? selectedInputDevice : "Select Mic Device"
                    font.pixelSize: 13
                    color: selectedInputDevice ? "white" : "#6B7280"
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
                onClicked: {
                    // TODO: Show device selection popup
                    selectedInputDevice = "Built-in Microphone"
                }
            }
        }
        
        // Controls section
        Text {
            text: "Controls"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 50
            radius: 8
            color: "#1a1a2e"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                // Recording indicator
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: isRecording ? "#EF4444" : "#4B5563"
                    
                    SequentialAnimation on opacity {
                        running: isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
                
                Text {
                    text: isRecording ? "Recording..." : (recordedFilePath ? "Recording complete" : "[ ● Start Recording ]")
                    font.pixelSize: 13
                    color: isRecording ? "#EF4444" : (recordedFilePath ? "#22C55E" : "#9CA3AF")
                    Layout.fillWidth: true
                }
                
                // Record/Stop button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: isRecording ? "#EF4444" : "#7C3AED"
                    
                    Text {
                        anchors.centerIn: parent
                        text: isRecording ? "■" : "●"
                        font.pixelSize: isRecording ? 12 : 16
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isRecording) {
                                // Stop recording and get the file path
                                if (typeof audioManager !== "undefined") {
                                    var filePath = audioManager.stopRecording()
                                    if (filePath) {
                                        root.recordedFilePath = "file://" + filePath
                                    }
                                }
                                root.isRecording = false
                            } else {
                                root.resetRecording()
                                // Start actual recording via AudioManager
                                if (typeof audioManager !== "undefined") {
                                    if (audioManager.startRecording()) {
                                        root.isRecording = true
                                    } else {
                                        console.log("Failed to start recording")
                                    }
                                } else {
                                    root.isRecording = true
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Trim Audio section
        Text {
            text: "✂ Trim Audio"
            font.pixelSize: 13
            color: "white"
            visible: recordedFilePath !== ""
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 8
            color: "#1a1a2e"
            visible: recordedFilePath !== ""
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                // Time display
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: formatTime(trimStart / 100 * recordingTime)
                        font.pixelSize: 11
                        color: "#9CA3AF"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Waveform placeholder
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        color: "#2a2a3e"
                        radius: 4
                        
                        // Simple waveform visualization
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            
                            Repeater {
                                model: 30
                                Rectangle {
                                    width: 3
                                    height: 5 + Math.random() * 20
                                    radius: 1.5
                                    color: "#7C3AED"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: formatTime(recordingTime)
                        font.pixelSize: 11
                        color: "#9CA3AF"
                    }
                }
                
                // Playback controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    
                    Repeater {
                        model: ["↻", "⏮", "▶", "⏭", "⇌"]
                        
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: modelData === "▶" ? "#7C3AED" : "#2a2a3e"
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 12
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
                        resetRecording()
                        audioName = ""
                        cancelled()
                    }
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 80
                height: 36
                radius: 6
                color: recordedFilePath ? "#7C3AED" : "#4B5563"
                
                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 13
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: recordedFilePath !== ""
                    onClicked: {
                        if (recordedFilePath) {
                            var finalName = audioName ? audioName : "Recording " + new Date().toLocaleTimeString()
                            audioAdded(finalName, recordedFilePath, "")
                            resetRecording()
                            audioName = ""
                        }
                    }
                }
            }
        }
    }
}
