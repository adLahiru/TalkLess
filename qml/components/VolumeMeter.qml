import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string label: "RMS Volume"
    property real value: 0.7
    property color meterColor: "#22C55E"
    property bool showWarning: false
    property string warningText: "Volume too high"
    
    width: 60
    height: 200
    color: "transparent"
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Meter bars
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a2e"
            radius: 4
            
            Column {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2
                
                Repeater {
                    model: 20
                    
                    Rectangle {
                        width: parent.width
                        height: (parent.height - 38) / 20
                        radius: 2
                        color: {
                            var position = (19 - index) / 20
                            if (position > value) return "#374151"
                            if (position > 0.8) return "#EF4444"
                            if (position > 0.6) return "#F59E0B"
                            return meterColor
                        }
                    }
                }
            }
        }
        
        // Label
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: label
            font.pixelSize: 10
            color: "#9CA3AF"
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Warning
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: showWarning
            spacing: 4
            
            Text {
                text: "⚠"
                font.pixelSize: 12
                color: "#F59E0B"
            }
            
            Text {
                text: warningText
                font.pixelSize: 10
                color: "#F59E0B"
            }
        }
    }
}
