import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    signal clicked()
    
    width: 160
    height: 120
    radius: 12
    color: "#1a1a2e"
    border.color: "#3a3a4e"
    border.width: 1
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 40
            height: 40
            radius: 8
            color: "transparent"
            border.color: "#4B5563"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "+"
                font.pixelSize: 24
                font.weight: Font.Light
                color: "#9CA3AF"
            }
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Add Audio"
            font.pixelSize: 13
            color: "#9CA3AF"
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
        
        onEntered: {
            root.border.color = "#7C3AED"
        }
        
        onExited: {
            root.border.color = "#3a3a4e"
        }
    }
}
