// VolumeMeter.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property string label: "Volume"
    property real level: 0.5  // 0.0 to 1.0
    property real dbValue: -15
    property color fillColorStart: "#22C55E"
    property color fillColorEnd: "#4ADE80"
    
    implicitHeight: contentColumn.height

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 10

        Text {
            text: root.label
            color: "#FFFFFF"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
        }

        // Volume bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#2A2A2A"
            radius: 16

            Rectangle {
                width: parent.width * root.level
                height: parent.height
                radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.fillColorStart }
                    GradientStop { position: 1.0; color: root.fillColorEnd }
                }
            }

            // dB indicator
            Rectangle {
                x: parent.width * root.level - width/2
                y: -8
                width: 44
                height: 20
                radius: 4
                color: root.fillColorStart

                Text {
                    anchors.centerIn: parent
                    text: root.dbValue.toFixed(0) + "dB"
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }
        }
    }
}
