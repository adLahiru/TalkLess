import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string actionName: ""
    property string hotkey: ""
    
    width: parent ? parent.width : 400
    height: 50
    color: "#12121a"
    radius: 8
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        
        Text {
            text: actionName + ":"
            font.pixelSize: 14
            color: "white"
            Layout.preferredWidth: 120
        }
        
        Item { Layout.fillWidth: true }
        
        Text {
            text: hotkey
            font.pixelSize: 14
            color: "#9CA3AF"
        }
        
        Item { Layout.preferredWidth: 20 }
        
        Rectangle {
            width: 28
            height: 28
            radius: 4
            color: "transparent"
            border.color: "#4B5563"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "↗"
                font.pixelSize: 14
                color: "#9CA3AF"
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
