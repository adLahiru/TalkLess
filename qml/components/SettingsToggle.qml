// SettingsToggle.qml
// Reusable toggle switch component for settings
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root
    
    property string label: ""
    property bool isOn: false
    property string onText: "ON"
    property string offText: "OFF"
    property bool showStatusText: true
    
    signal toggled(bool value)
    
    implicitHeight: 28
    implicitWidth: toggleRow.implicitWidth

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    RowLayout {
        id: toggleRow
        anchors.fill: parent
        spacing: 12

        // Toggle switch
        Rectangle {
            id: toggleBg
            width: 52
            height: 28
            radius: 14
            color: root.isOn ? "#22C55E" : "#3A3A3A"

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: "#FFFFFF"
                x: root.isOn ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                Behavior on x {
                    NumberAnimation { duration: 150 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.isOn = !root.isOn
                    root.toggled(root.isOn)
                }
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        // Label
        Text {
            visible: root.label !== ""
            text: root.label
            color: "#FFFFFF"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
        }

        // Status text (ON/OFF)
        Text {
            visible: root.showStatusText
            text: root.isOn ? root.onText : root.offText
            color: "#666666"
            font.pixelSize: 12
        }
    }
}
