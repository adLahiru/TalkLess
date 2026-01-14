// DropdownSelector.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Rectangle {
    id: root

    property string placeholder: "Select..."
    property string selectedValue: ""
    property string selectedId: ""
    property string icon: ""
    property var model: []  // Array of objects with {id, name, isDefault}
    property bool openUpward: false  // When true, popup opens above the control

    signal itemSelected(string id, string name)
    signal aboutToOpen

    // Internal list model to properly manage items
    property var internalModel: []

    onModelChanged: {
        // Copy model to internal list to avoid binding issues
        var items = [];
        if (model && model.length > 0) {
            for (var i = 0; i < model.length; i++) {
                var rawId = model[i] && model[i].id;
                var rawName = model[i] && model[i].name;
                items.push({
                    // IMPORTANT: normalize ids to string to avoid "1" vs 1 mismatch
                    id: (rawId !== undefined && rawId !== null) ? String(rawId) : "",
                    name: (rawName !== undefined && rawName !== null) ? String(rawName) : "",
                    isDefault: (model[i] && model[i].isDefault) ? true : false
                });
            }
        }
        internalModel = items;

        // Update selected name if models change
        updateSelectedName();
    }

    onSelectedIdChanged: updateSelectedName()

    function updateSelectedName() {
        var sid = (selectedId !== undefined && selectedId !== null) ? String(selectedId) : "";

        if (sid.length === 0) {
            selectedValue = "";
            return;
        }

        for (var i = 0; i < internalModel.length; i++) {
            if (internalModel[i].id === sid) {
                selectedValue = internalModel[i].name;
                return;
            }
        }

        // If selectedId is not in the model, show placeholder
        selectedValue = "";
    }

    height: 50
    color: dropdownMouseArea.containsMouse || dropdownPopup.visible ? Colors.surfaceLight : Colors.surface
    radius: 12
    border.width: 1
    border.color: dropdownPopup.visible ? Colors.borderLight : Colors.border

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Icon
        Text {
            text: root.icon
            font.pixelSize: 18
            visible: root.icon.length > 0
        }

        Text {
            text: root.selectedValue.length > 0 ? root.selectedValue : root.placeholder
            color: root.selectedValue.length > 0 ? Colors.textPrimary : Colors.textSecondary
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Dropdown arrow
        Text {
            text: dropdownPopup.visible ? "▲" : "▼"
            color: Colors.textSecondary
            font.pixelSize: 10
        }
    }

    MouseArea {
        id: dropdownMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            if (dropdownPopup.visible) {
                dropdownPopup.close();
            } else {
                root.aboutToOpen();
                dropdownPopup.open();
            }
        }
    }

    // Dropdown popup menu
    Popup {
        id: dropdownPopup
        // Position based on openUpward property
        y: root.openUpward ? -height - 4 : parent.height + 4
        x: 0
        width: parent.width
        height: Math.min(itemColumn.implicitHeight + 16, 300)
        padding: 8
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 1000

        background: Rectangle {
            color: Colors.surface
            radius: 10
            border.color: Colors.border
            border.width: 1

            // Shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                z: -1
                color: Colors.shadow
                radius: 12
                border.color: "transparent"
                border.width: 0
                opacity: 0.3
            }
        }

        contentItem: Flickable {
            id: flickable
            clip: true
            contentHeight: itemColumn.implicitHeight
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: itemColumn
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.internalModel

                    delegate: Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index

                        width: itemColumn.width
                        height: 42
                        radius: 8
                        color: itemMouseArea.containsMouse ? Colors.surfaceLight : (root.selectedId === modelData.id ? Colors.surfaceDark : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: itemDelegate.modelData.name
                                color: root.selectedId === itemDelegate.modelData.id ? Colors.textPrimary : Colors.textSecondary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: root.selectedId === itemDelegate.modelData.id ? Font.Medium : Font.Normal
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Default indicator badge
                            Rectangle {
                                visible: itemDelegate.modelData.isDefault
                                width: defaultLabel.width + 10
                                height: 18
                                radius: 4
                                color: Qt.lighter(Colors.success, 1.8) // Very light green background

                                Text {
                                    id: defaultLabel
                                    anchors.centerIn: parent
                                    text: "Default"
                                    color: Colors.success
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }

                            // Selected checkmark
                            Text {
                                visible: root.selectedId === itemDelegate.modelData.id
                                text: "✓"
                                color: Colors.success
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Keep ids as strings
                                root.selectedId = String(itemDelegate.modelData.id);
                                root.selectedValue = itemDelegate.modelData.name;
                                root.itemSelected(root.selectedId, root.selectedValue);
                                dropdownPopup.close();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }
                }

                // Empty state when no devices
                Rectangle {
                    visible: root.internalModel.length === 0
                    width: itemColumn.width
                    height: 50
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "No devices found"
                        color: Colors.textSecondary
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 14
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: flickable.contentHeight > flickable.height
                policy: flickable.contentHeight > flickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 120
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 120
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 80
            }
        }
    }
}
