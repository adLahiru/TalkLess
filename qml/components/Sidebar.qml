// SideBar.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    // Size controlled by Layout properties from parent
    color: "#1F1F1F"          // dark panel
    radius: 10

    // Load Outfit font from Google Fonts
    FontLoader {
        id: outfitFont
        source: "https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4TC1C4G-EiAou6Y.ttf"
    }

    property int currentIndex: 0
    signal selected(string route)

    // Menu model: you can replace iconSource with your svg/png
    ListModel {
        id: menuModel
        ListElement { title: "Soundboard";            route: "soundboard"; iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_soundboard.svg" }
        ListElement { title: "Audio Playback Engine"; route: "engine";     iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_play.svg"  }
        ListElement { title: "Macros & Automation";   route: "macros";     iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_macros.svg" }
        ListElement { title: "Application Settings";  route: "settings";   iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_settings.svg"  }
        ListElement { title: "Statistics & Reporting";route: "stats";      iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_stats.svg" }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // ---- Header (title image) ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Title logo image
            Image {
                id: titleImage
                source: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_logo.png"
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                Layout.preferredHeight: 40
                Layout.preferredWidth: 120
                Layout.alignment: Qt.AlignLeft
            }

            Item { Layout.fillWidth: true }
        }

        // Divider line
        Image {
            source: "qrc:/qt/qml/TalkLess/resources/icons/decorations/ic_sidebar_divider.svg"
            Layout.fillWidth: true
            fillMode: Image.Stretch
            Layout.preferredHeight: 2
            Layout.bottomMargin: 6
        }

        // ---- Menu list ----
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: menuModel
            interactive: true

            delegate: Item {
                id: rowItem
                width: list.width
                height: 54

                required property int index
                required property string title
                required property string route
                required property string iconSource

                readonly property bool isSelected: (rowItem.index === root.currentIndex)

                // Highlight pill (selected)
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: rowItem.isSelected
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#3B82F6" }
                        GradientStop { position: 1.0; color: "#D214FD" }
                    }
                }

                // Subtle hover background (non-selected)
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: !rowItem.isSelected && mouse.containsMouse
                    color: "#1B1D24"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Icon circle
                    Rectangle {
                        width: 34; height: 34
                        radius: 12
                        // Selected: white background, Unselected: deep blue background
                        color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"
                        border.width: 1
                        border.color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"

                        Image {
                            id: iconImage
                            anchors.centerIn: parent
                            source: rowItem.iconSource
                            width: 18; height: 18
                            fillMode: Image.PreserveAspectFit
                            visible: false  // Hidden, shown through MultiEffect
                        }

                        // Icon colorization effect
                        MultiEffect {
                            anchors.fill: iconImage
                            source: iconImage
                            colorization: 1.0
                            // Selected: blue icon, Unselected: white icon
                            colorizationColor: rowItem.isSelected ? "#3B82F6" : "#DBFFFFFF"
                        }
                    }

                    Text {
                        text: rowItem.title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: "#FFFFFF"
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.currentIndex = rowItem.index
                        root.selected(rowItem.route)
                    }
                }
            }
        }
    }
}
