import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    color: "#12121a"
    radius: 12
    
    property int currentTabIndex: 0  // 0: Add Audio, 1: Record Audio
    
    signal audioAdded(string name, string filePath, string imagePath)
    signal cancelled()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // Tab Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 22
            color: "#1a1a2e"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                
                // Add Audio Tab
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: currentTabIndex === 0 ? "#2a2a3e" : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Add Audio"
                        font.pixelSize: 13
                        font.weight: currentTabIndex === 0 ? Font.Medium : Font.Normal
                        color: currentTabIndex === 0 ? "white" : "#9CA3AF"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: currentTabIndex = 0
                    }
                }
                
                // Record Audio Tab
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: currentTabIndex === 1 ? "#7C3AED" : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Record Audio"
                        font.pixelSize: 13
                        font.weight: currentTabIndex === 1 ? Font.Medium : Font.Normal
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: currentTabIndex = 1
                    }
                }
            }
        }
        
        // Content Area
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTabIndex
            
            // Add Audio Content
            AddAudioContent {
                id: addAudioContent
                onAudioAdded: function(name, filePath, imagePath) {
                    root.audioAdded(name, filePath, imagePath)
                }
                onCancelled: root.cancelled()
            }
            
            // Record Audio Content
            RecordAudioContent {
                id: recordAudioContent
                onAudioAdded: function(name, filePath, imagePath) {
                    root.audioAdded(name, filePath, imagePath)
                }
                onCancelled: root.cancelled()
            }
        }
    }
}
