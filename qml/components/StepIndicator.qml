// StepIndicator.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property string label: "Intensity"
    property int steps: 10
    property int activeSteps: 5
    property string minLabel: "Low"
    property string maxLabel: "High"
    property string description: ""
    property color activeColor: "#22C55E"
    property color inactiveColor: "#3A3A3A"
    
    implicitHeight: contentColumn.height

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                color: "#FFFFFF"
                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                font.pixelSize: 14
            }

            Item { Layout.fillWidth: true }

            // Step indicator
            Row {
                spacing: 3
                Repeater {
                    model: root.steps
                    Rectangle {
                        width: 14
                        height: 18
                        radius: 2
                        color: stepIndex < root.activeSteps ? root.activeColor : root.inactiveColor
                        
                        required property int index
                        property int stepIndex: index
                    }
                }
            }
        }

        // Min/Max labels
        RowLayout {
            Layout.fillWidth: true
            Text { 
                text: root.minLabel
                color: "#666666"
                font.pixelSize: 11 
            }
            Item { Layout.fillWidth: true }
            Text { 
                text: root.maxLabel
                color: "#666666"
                font.pixelSize: 11 
            }
        }

        // Description
        Text {
            text: root.description
            color: "#666666"
            font.pixelSize: 12
            visible: root.description.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
