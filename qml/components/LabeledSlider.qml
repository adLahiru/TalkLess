// LabeledSlider.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string label: "Label"
    property real from: 0
    property real to: 100
    property real value: 50
    property string unit: ""
    property string minLabel: ""
    property string maxLabel: ""
    property string description: ""
    property bool showInlineValue: true

    // Gradient colors for slider fill
    property color gradientStart: "#3B82F6"
    property color gradientEnd: Colors.accent

    signal sliderValueChanged(real newValue)

    implicitHeight: contentColumn.height

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 6

        // Label and slider on same line
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: root.label
                color: "#FFFFFF"
                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                font.pixelSize: 14
            }

            // Slider with value indicator
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                // Value indicator above slider
                Text {
                    id: valueLabel
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - 16) + 8 - width / 2
                    y: -4
                    text: Math.round(root.value) + root.unit
                    color: "#FFFFFF"
                    font.pixelSize: 11
                    visible: root.showInlineValue
                }

                Slider {
                    id: slider
                    anchors.fill: parent
                    from: root.from
                    to: root.to
                    value: root.value

                    onValueChanged: {
                        root.value = value;
                        root.sliderValueChanged(value);
                    }

                    background: Rectangle {
                        x: slider.leftPadding
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.availableWidth
                        height: 6
                        radius: 3
                        color: "#3A3A3A"

                        Rectangle {
                            width: slider.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: root.gradientStart
                                }
                                GradientStop {
                                    position: 1.0
                                    color: root.gradientEnd
                                }
                            }
                        }
                    }

                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: "#FFFFFF"
                    }
                }
            }
        }

        // Min/Max labels
        RowLayout {
            Layout.fillWidth: true
            visible: root.minLabel.length > 0 || root.maxLabel.length > 0

            Text {
                text: root.minLabel
                color: "#666666"
                font.pixelSize: 11
            }
            Item {
                Layout.fillWidth: true
            }
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
