import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property string currentValue: ""
    property var model: []
    property int currentIndex: 0
    property bool enabled: true
    
    signal valueChanged(string value)
    
    width: 280
    height: 40
    radius: 6
    color: enabled ? Colors.surface : Qt.darker(Colors.surface, 1.2)
    border.color: dropdownPopup.visible ? Colors.primary : Colors.border
    border.width: 1
    clip: true
    opacity: enabled ? 1.0 : 0.6
    
    // Current selection display
    Text {
        id: displayText
        anchors {
            left: parent.left
            right: dropIcon.left
            leftMargin: 16
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        text: currentValue || (model.length > 0 ? model[currentIndex] : "No devices")
        font.pixelSize: 14
        color: Colors.textPrimary
        elide: Text.ElideRight
    }
    
    // Dropdown icon
    Text {
        id: dropIcon
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        text: dropdownPopup.visible ? "▲" : "▼"
        font.pixelSize: 10
        color: Colors.textSecondary
    }
    
    // Popup with device list
    Popup {
        id: dropdownPopup
        y: parent.height + 2
        width: parent.width
        height: Math.min(200, model.length * 40 + 2)
        padding: 1
        background: Rectangle {
            color: Colors.surface
            border.color: Colors.border
            radius: 6
        }
        
        contentItem: ListView {
            clip: true
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { 
                width: 6
                policy: ScrollBar.AsNeeded
            }
            
            delegate: Rectangle {
                width: dropdownPopup.width - 2
                height: 38
                color: ListView.isCurrentItem ? Colors.surfaceLight : "transparent"
                
                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 16
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData
                    color: Colors.textPrimary
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        currentIndex = index
                        currentValue = modelData
                        valueChanged(currentValue)
                        dropdownPopup.close()
                    }
                }
            }
        }
    }
    
    // Click handler
    MouseArea {
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled && model.length > 0) {
                dropdownPopup.opened ? dropdownPopup.close() : dropdownPopup.open()
            }
        }
    }
}
