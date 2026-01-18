// SettingsTabSelector.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: 56

    // Current selected index
    property int currentIndex: 0

    // Signal when tab changes - just emits the index
    signal tabSelected(int index)

    // Tab model - just titles
    ListModel {
        id: tabModel
        ListElement {
            title: "Microphone Controller"
        }
        ListElement {
            title: "Language & Theme"
        }
        ListElement {
            title: "Audio & Devices"
        }
        ListElement {
            title: "Hotkeys"
        }
        ListElement {
            title: "AI & Productivity Tools"
        }
        ListElement {
            title: "System"
        }
    }

    // Load Inter font for tab text
    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Gray background rectangle container
    Rectangle {
        id: backgroundContainer
        anchors.centerIn: parent
        width: tabRow.width + 20
        height: 48
        radius: 24
        color: Colors.surfaceDark
    }

    // Tab row on top of the gray background
    RowLayout {
        id: tabRow
        anchors.centerIn: parent
        height: 40
        spacing: 8

        Repeater {
            id: tabRepeater
            model: tabModel

            delegate: Rectangle {
                id: tabItem
                Layout.preferredHeight: 40
                Layout.preferredWidth: tabText.implicitWidth + 32
                radius: 20

                required property int index
                required property string title

                readonly property bool isSelected: tabItem.index === root.currentIndex
                layer.enabled: true

                // Gradient background for selected tab
                gradient: tabItem.isSelected ? selectedGradient : null
                color: tabItem.isSelected ? "transparent" : "transparent"

                Gradient {
                    id: selectedGradient
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Colors.accent
                    }
                    GradientStop {
                        position: 1.0
                        color: Colors.secondary
                    }
                }

                Text {
                    id: tabText
                    anchors.centerIn: parent
                    text: tabItem.title
                    color: tabItem.isSelected ? Colors.textOnPrimary : Colors.textPrimary
                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: tabItem.isSelected ? Font.Medium : Font.Normal
                    opacity: tabItem.isSelected ? 1.0 : 0.7
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.currentIndex = tabItem.index;
                        root.tabSelected(tabItem.index);
                    }

                    onEntered: {
                        if (!tabItem.isSelected) {
                            tabText.opacity = 0.9;
                        }
                    }

                    onExited: {
                        if (!tabItem.isSelected) {
                            tabText.opacity = 0.7;
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
