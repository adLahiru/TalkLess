// SettingsPanel.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Rectangle {
    id: root
    
    property string title: "Panel Title"
    
    default property alias content: contentContainer.data
    
    color: Colors.panelBg
    radius: 16

    FontLoader {
        id: poppinsFont
        source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLEj6Z1JlFc-K.ttf"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // Title
        Text {
            text: root.title
            color: Colors.textPrimary
            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        // Content container
        ColumnLayout {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
        }
    }
}
