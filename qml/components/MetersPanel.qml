import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    width: 280
    color: "#12121a"
    radius: 12
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // Header with icons
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "F1"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "white"
            }
            
            Item { Layout.fillWidth: true }
            
            // Icon buttons
            Repeater {
                model: ["⚙", "+", "●", "◫", "🔊"]
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: index === 4 ? "#7C3AED" : "#2a2a3e"
                    
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
        
        // Title
        Text {
            text: "Meters & Monitoring"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "white"
        }
        
        // Volume meters
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            spacing: 32
            Layout.alignment: Qt.AlignHCenter
            
            VolumeMeter {
                label: "RMS Volume"
                value: 0.85
                meterColor: "#22C55E"
                showWarning: true
                warningText: "Volume too high"
            }
            
            VolumeMeter {
                label: "Mic Input"
                value: 0.4
                meterColor: "#3B82F6"
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
