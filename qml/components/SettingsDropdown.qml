// SettingsDropdown.qml
// Reusable dropdown selector component for settings
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root
    
    property string label: ""
    property string value: ""
    property var options: []  // Array of options
    property bool showLabel: true
    
    signal optionSelected(string option)
    
    implicitHeight: 40
    implicitWidth: showLabel ? labelText.width + 12 + dropdown.width : dropdown.width

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Label (optional)
        Text {
            id: labelText
            visible: root.showLabel && root.label !== ""
            text: root.label
            color: "#FFFFFF"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 14
        }

        // Dropdown container
        Rectangle {
            id: dropdown
            Layout.preferredWidth: 200
            Layout.preferredHeight: 40
            color: "#2A2A2A"
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: root.value
                    color: "#AAAAAA"
                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }

                Text {
                    text: "▼"
                    color: "#666666"
                    font.pixelSize: 12
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Toggle dropdown visibility or emit signal
                    console.log("Dropdown clicked:", root.label)
                    root.optionSelected(root.value)
                }
            }
        }
    }
}
