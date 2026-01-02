import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string featureName: ""
    property bool isEnabled: true
    
    signal toggled(bool enabled)
    
    width: parent ? parent.width : 400
    height: 50
    color: "#12121a"
    radius: 8
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        
        Text {
            text: featureName
            font.pixelSize: 14
            color: "white"
            Layout.fillWidth: true
        }
        
        ToggleSwitch {
            checked: root.isEnabled
            onCheckedChanged: {
                if (root.isEnabled !== checked) {
                    root.isEnabled = checked
                    root.toggled(checked)
                }
            }
        }
    }
}
