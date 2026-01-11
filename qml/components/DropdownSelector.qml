// DropdownSelector.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string placeholder: "Select..."
    property string selectedValue: ""
    property string selectedId: ""
    property string icon: ""
    property var model: []  // Array of objects with {id, name, isDefault}
    
    signal itemSelected(string id, string name)
    signal aboutToOpen()
    // Internal list model to properly manage items
    property var internalModel: []
    
    onModelChanged: {
        // Copy model to internal list to avoid binding issues
        var items = []
        if (model && model.length > 0) {
            for (var i = 0; i < model.length; i++) {
                items.push({
                    id: model[i].id || "",
                    name: model[i].name || "",
                    isDefault: model[i].isDefault || false
                })
            }
        }
        internalModel = items
        
        // Update selected name if models change
        updateSelectedName()
    }

    onSelectedIdChanged: updateSelectedName()

    function updateSelectedName() {
        if (!selectedId) {
            selectedValue = ""
            return
        }
        for (var i = 0; i < internalModel.length; i++) {
            if (internalModel[i].id === selectedId) {
                selectedValue = internalModel[i].name
                return
            }
        }
        // If not found in model, it might still be loading or model not yet populated
        // We don't clear selectedValue here to avoid flickering if it was already set
    }
    
    height: 50
    color: dropdownMouseArea.containsMouse || dropdownPopup.visible ? "#333333" : "#2A2A2A"
    radius: 12
    border.width: 1
    border.color: dropdownPopup.visible ? "#555555" : "#3A3A3A"

    Behavior on color {
        ColorAnimation { duration: 150 }
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
            color: root.selectedValue.length > 0 ? "#FFFFFF" : "#AAAAAA"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Dropdown arrow
        Text {
            text: dropdownPopup.visible ? "▲" : "▼"
            color: "#888888"
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
                dropdownPopup.close()
            } else {
                root.aboutToOpen()
                dropdownPopup.open()
            }
        }

    }

    // Dropdown popup menu
    Popup {
        id: dropdownPopup
        y: parent.height + 4
        x: 0
        width: parent.width
        height: Math.min(itemColumn.implicitHeight + 16, 300)
        padding: 8
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 1000
        
        background: Rectangle {
            color: "#1A1A1A"
            radius: 10
            border.color: "#444444"
            border.width: 1
            
            // Shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                z: -1
                color: "transparent"
                radius: 12
                border.color: "#000000"
                border.width: 4
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
                        color: itemMouseArea.containsMouse ? "#2D2D2D" : 
                               (root.selectedId === modelData.id ? "#252525" : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: itemDelegate.modelData.name
                                color: root.selectedId === itemDelegate.modelData.id ? "#FFFFFF" : "#CCCCCC"
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
                                color: "#1E3A2F"

                                Text {
                                    id: defaultLabel
                                    anchors.centerIn: parent
                                    text: "Default"
                                    color: "#22C55E"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }

                            // Selected checkmark
                            Text {
                                visible: root.selectedId === itemDelegate.modelData.id
                                text: "✓"
                                color: "#22C55E"
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
                                root.selectedId = itemDelegate.modelData.id
                                root.selectedValue = itemDelegate.modelData.name
                                root.itemSelected(itemDelegate.modelData.id, itemDelegate.modelData.name)
                                dropdownPopup.close()
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 100 }
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
                        color: "#666666"
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
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120 }
            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 120 }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 80 }
        }
    }
}
