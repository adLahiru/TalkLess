import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property int currentIndex: 0
    property var tabs: ["Audio Devices", "Hotkeys", "Features", "UI & Display", "Updates"]
    
    signal tabClicked(int index)
    
    height: 50
    color: "#1a1a2e"
    radius: 25
    
    RowLayout {
        anchors.centerIn: parent
        spacing: 0
        
        Repeater {
            model: tabs
            
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                radius: 20
                color: currentIndex === index ? "#7C3AED" : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 13
                    font.weight: currentIndex === index ? Font.Medium : Font.Normal
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        currentIndex = index
                        tabClicked(index)
                    }
                }
            }
        }
    }
}
