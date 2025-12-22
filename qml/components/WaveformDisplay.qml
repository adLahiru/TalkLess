import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property real startTime: 1.30
    property real endTime: 3.30
    property real currentPosition: 0.5
    
    height: 40
    color: "transparent"
    
    RowLayout {
        anchors.fill: parent
        spacing: 8
        
        Text {
            text: formatTime(startTime)
            font.pixelSize: 11
            color: "#9CA3AF"
        }
        
        // Waveform visualization
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#1a1a2e"
            radius: 4
            clip: true
            
            // Waveform bars
            Row {
                id: waveformRow
                anchors.centerIn: parent
                spacing: 2
                
                // Pre-generated heights to avoid Math.random() in binding
                property var barHeights: [12, 18, 8, 22, 14, 20, 10, 16, 24, 12, 18, 9, 21, 15, 19, 11, 17, 23, 13, 16, 8, 20, 14, 22, 10, 18, 12, 24, 16, 20]
                
                Repeater {
                    model: 30
                    
                    Rectangle {
                        width: 3
                        height: waveformRow.barHeights[index]
                        radius: 1
                        color: index < 30 * currentPosition ? "#7C3AED" : "#4B5563"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            
            // Selection overlay
            Rectangle {
                x: parent.width * 0.3
                width: parent.width * 0.4
                height: parent.height
                color: Qt.rgba(124, 58, 237, 0.2)
                border.color: "#7C3AED"
                border.width: 1
                radius: 4
            }
        }
        
        Text {
            text: formatTime(endTime)
            font.pixelSize: 11
            color: "#9CA3AF"
        }
    }
    
    function formatTime(time) {
        var mins = Math.floor(time)
        var secs = Math.round((time - mins) * 100)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}
