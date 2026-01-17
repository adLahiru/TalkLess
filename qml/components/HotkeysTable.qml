import QtQuick 2.15
import QtQuick.Controls 2.15
import "../styles"

Item {
    id: root
    width: 900
    property string title: ""
    property var model: null

    // table options
    property bool showHeader: false
    property bool showWarning: false

    property string headerCol1: "Slot Name"
    property string headerCol2: "Assigned Hotkeys"
    property string headerCol3: "Actions"

    property int col1Width: 330
    property int col2Width: 320

    property string primaryText: "Reassign"
    property string secondaryText: "Reset" // or "Delete"

    signal primaryClicked(int id)
    signal secondaryClicked(int id)

    implicitHeight: titleLabel.implicitHeight + (showHeader ? (headerRect.height + 14) : 0) + list.contentHeight + (showWarning ? (warningRow.implicitHeight + 14) : 0) + 10

    Label {
        id: titleLabel
        text: root.title
        color: Colors.textPrimary
        font.pixelSize: 20
        font.weight: Font.DemiBold
        anchors.left: parent.left
        anchors.top: parent.top
    }

    Rectangle {
        id: headerRect
        visible: root.showHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 16
        height: 46
        radius: 12
        color: Colors.surface

        Row {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 18

            Text {
                width: root.col1Width
                text: root.headerCol1
                color: Colors.textSecondary
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: root.col2Width
                text: root.headerCol2
                color: Colors.textSecondary
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: 1
                height: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.headerCol3
                color: Colors.textSecondary
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.showHeader ? headerRect.bottom : titleLabel.bottom
        anchors.topMargin: root.showHeader ? 14 : 22
        height: contentHeight
        spacing: 12
        clip: false
        model: root.model

        delegate: Rectangle {
            id: delegateRoot
            
            // Access model data - works for both C++ models and JS arrays
            // For C++ QAbstractListModel: model.roleName
            // For JS array: modelData.property
            property int itemId: model.id !== undefined ? model.id : (modelData ? modelData.id : -1)
            property string itemTitle: model.title !== undefined ? model.title : (modelData ? modelData.title : "")
            property string itemHotkey: model.hotkey !== undefined ? model.hotkey : (modelData ? modelData.hotkey : "")

            width: ListView.view ? ListView.view.width : parent.width
            height: 62
            radius: 12
            color: Colors.surfaceLight

            // subtle inner shadow feel
            border.color: Colors.border
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 18

                Text {
                    width: root.col1Width
                    text: delegateRoot.itemTitle || ""
                    color: Colors.textPrimary
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: root.col2Width
                    text: delegateRoot.itemHotkey || "Not assigned"
                    color: delegateRoot.itemHotkey ? Colors.textSecondary : Colors.textTertiary
                    font.pixelSize: 14
                    font.italic: !delegateRoot.itemHotkey
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 1
                    height: 1
                } // spacer

                Row {
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter

                    // Reassign (gradient)
                    Button {
                        id: primaryButton
                        text: root.primaryText
                        onClicked: root.primaryClicked(delegateRoot.itemId)

                        contentItem: Text {
                            text: primaryButton.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 10
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Colors.gradientPrimaryStart
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Colors.gradientPrimaryEnd
                                }
                            }
                        }
                    }

                    // Reset/Delete (dark)
                    Button {
                        id: secondaryButton
                        text: root.secondaryText
                        onClicked: root.secondaryClicked(delegateRoot.itemId)

                        contentItem: Text {
                            text: secondaryButton.text
                            color: Colors.textPrimary
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 10
                            color: secondaryButton.down ? Colors.surfaceDark : Colors.surface
                            border.color: Colors.border
                            border.width: 1
                        }
                    }
                }
            }
        }
    }

    Row {
        id: warningRow
        visible: root.showWarning
        spacing: 10
        anchors.left: parent.left
        anchors.top: list.bottom
        anchors.topMargin: 16

        Text {
            text: "⚠"
            color: "#F6D14A"
            font.pixelSize: 16
        }
        Text {
            text: "Warning if assigned elsewhere"
            color: "#CFCFCF"
            font.pixelSize: 14
        }
    }
}
