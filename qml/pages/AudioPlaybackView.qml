import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

Item {
    id: root

    // Signal to request navigation to soundboard for simulation
    signal startSimulationRequested()

    // Banner Area
    BackgroundBanner {
        id: banner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        displayText: "Settings & Configuration, Manage and trigger your sound clips"
    }

    // Main Content Container
    ColumnLayout {
        anchors.top: banner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 20
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 20

        // Tab Selector
        Rectangle {
            id: tabSelector
            Layout.fillWidth: true
            height: 56
            color: "transparent"

            property int currentIndex: 1 // Default to Test Call Simulation

            ListModel {
                id: tabModel
                ListElement { title: "Playback Dashboard" }
                ListElement { title: "Test Call Simulation" }
            }

            Rectangle {
                anchors.centerIn: tabRow
                width: tabRow.width + 20
                height: 48
                radius: 24
                color: Colors.surfaceDark
            }

            RowLayout {
                id: tabRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: tabModel

                    delegate: Rectangle {
                        id: tabItem
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: tabText.implicitWidth + 32
                        radius: 20
                        layer.enabled: true

                        required property int index
                        required property string title

                        readonly property bool isSelected: tabItem.index === tabSelector.currentIndex

                        gradient: tabItem.isSelected ? selectedGradient : null
                        color: tabItem.isSelected ? "white" : "transparent"

                        Gradient {
                            id: selectedGradient
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Colors.gradientPrimaryStart }
                            GradientStop { position: 1.0; color: Colors.gradientPrimaryEnd }
                        }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: tabItem.title
                            color: tabItem.isSelected ? Colors.textOnPrimary : Colors.textPrimary
                            font.pixelSize: 15
                            font.weight: tabItem.isSelected ? Font.Medium : Font.Normal
                            opacity: tabItem.isSelected ? 1.0 : 0.7
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: tabSelector.currentIndex = tabItem.index
                            onEntered: {
                                if (!tabItem.isSelected) tabText.opacity = 0.9
                            }
                            onExited: {
                                if (!tabItem.isSelected) tabText.opacity = 0.7
                            }
                        }
                        
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }

        // Test Call Simulation Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabSelector.currentIndex === 1
            color: "#0D0D0D"
            radius: 12
            border.width: 1
            border.color: "#1A1A1C"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20

                // Title
                Text {
                    text: "Test Call Simulation"
                    color: Colors.white
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                // Description
                Text {
                    text: "This will simulate a call using your selected playback and mic devices."
                    color: Colors.textSecondary
                    font.pixelSize: 14
                    Layout.preferredWidth: 600
                    wrapMode: Text.WordWrap
                }

                Item { height: 10; width: 1 }

                // Start Simulation Button
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 50
                    color: startSimMA.containsMouse ? Colors.surfaceLight : "transparent"
                    border.width: 1
                    border.color: Colors.textSecondary
                    radius: 4

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "▶"
                            color: Colors.white
                            font.pixelSize: 14
                        }

                        Text {
                            text: "Start Simulation"
                            color: Colors.white
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: startSimMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            soundboardService.startTestCallSimulation();
                            root.startSimulationRequested();
                        }
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item { height: 10; width: 1 }

                // Record simulation checkbox
                RowLayout {
                    spacing: 10

                    Rectangle {
                        id: recordCheckbox
                        width: 18
                        height: 18
                        radius: 4
                        color: recordCheckbox.checked ? "#6366f1" : "transparent"
                        border.width: recordCheckbox.checked ? 0 : 1
                        border.color: Colors.textSecondary

                        property bool checked: true

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                            visible: recordCheckbox.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recordCheckbox.checked = !recordCheckbox.checked
                        }
                    }

                    Text {
                        text: "Record simulation"
                        color: Colors.textSecondary
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recordCheckbox.checked = !recordCheckbox.checked
                        }
                    }
                }

                // Loop playback test checkbox
                RowLayout {
                    spacing: 10

                    Rectangle {
                        id: loopCheckbox
                        width: 18
                        height: 18
                        radius: 4
                        color: loopCheckbox.checked ? "#6366f1" : "transparent"
                        border.width: loopCheckbox.checked ? 0 : 1
                        border.color: Colors.textSecondary

                        property bool checked: true

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                            visible: loopCheckbox.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loopCheckbox.checked = !loopCheckbox.checked
                        }
                    }

                    Text {
                        text: "Loop playback test"
                        color: Colors.textSecondary
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loopCheckbox.checked = !loopCheckbox.checked
                        }
                    }
                }

                Item { height: 10; width: 1 }

                // Action buttons row
                RowLayout {
                    spacing: 20

                    // Play Last Recording button
                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 40
                        color: playLastMA.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                        radius: 8
                        border.width: 1
                        border.color: Colors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "▶"
                                color: Colors.accent
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Play Last Recording"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: playLastMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                soundboardService.playLastTestCallRecording();
                            }
                        }

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Open Recordings Folder button
                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 40
                        color: openFolderMA.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                        radius: 8
                        border.width: 1
                        border.color: Colors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "📂"
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Open Recordings Folder"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: openFolderMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                soundboardService.openTestCallRecordingsFolder();
                            }
                        }

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Vertical Spacer
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // Playback Dashboard Card
        Rectangle {
            id: playbackDashboardCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabSelector.currentIndex === 0
            color: "#0D0D0D"
            radius: 12
            border.width: 1
            border.color: "#1A1A1C"

            // State for selected soundboard
            property int selectedBoardId: -1
            property string selectedBoardName: ""
            property var clipsData: []

            // Function to load clips for selected board
            function loadClipsForBoard(boardId) {
                if (boardId >= 0 && soundboardService) {
                    clipsData = soundboardService.getClipsForBoardVariant(boardId);
                } else {
                    clipsData = [];
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Header row with dropdown
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Title
                    Text {
                        text: "Playback Dashboard"
                        color: Colors.white
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    // Select Soundboard dropdown
                    Rectangle {
                        id: soundboardDropdown
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 40
                        radius: 8
                        color: dropdownMa.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                        border.width: 1
                        border.color: Colors.border

                        property bool isOpen: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: playbackDashboardCard.selectedBoardName || "Select Soundboard"
                                color: playbackDashboardCard.selectedBoardName ? Colors.textPrimary : Colors.textSecondary
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            Text {
                                text: soundboardDropdown.isOpen ? "▲" : "▼"
                                color: Colors.textSecondary
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: dropdownMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: soundboardDropdown.isOpen = !soundboardDropdown.isOpen
                        }

                        // Dropdown popup
                        Rectangle {
                            id: dropdownPopup
                            anchors.top: parent.bottom
                            anchors.left: parent.left
                            anchors.topMargin: 4
                            width: parent.width
                            height: Math.min(boardsList.contentHeight + 8, 200)
                            radius: 8
                            color: Colors.surface
                            border.width: 1
                            border.color: Colors.border
                            visible: soundboardDropdown.isOpen
                            z: 100

                            ListView {
                                id: boardsList
                                anchors.fill: parent
                                anchors.margins: 4
                                clip: true
                                model: soundboardService ? soundboardService.listBoardsForDropdown() : []

                                delegate: Rectangle {
                                    id: boardDelegate
                                    width: boardsList.width
                                    height: 36
                                    radius: 6
                                    color: boardItemMa.containsMouse ? Colors.surfaceLight : "transparent"

                                    required property var modelData
                                    required property int index

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: boardDelegate.modelData.name || ""
                                        color: Colors.textPrimary
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: boardItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            playbackDashboardCard.selectedBoardId = boardDelegate.modelData.id;
                                            playbackDashboardCard.selectedBoardName = boardDelegate.modelData.name;
                                            playbackDashboardCard.loadClipsForBoard(boardDelegate.modelData.id);
                                            soundboardDropdown.isOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Clips list
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        id: clipsColumn
                        width: parent.width
                        spacing: 8

                        // Empty state
                        Text {
                            visible: playbackDashboardCard.clipsData.length === 0
                            text: playbackDashboardCard.selectedBoardId >= 0 
                                ? "No clips in this soundboard" 
                                : "Select a soundboard to view clips"
                            color: Colors.textSecondary
                            font.pixelSize: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Clips repeater
                        Repeater {
                            id: clipsRepeater
                            model: playbackDashboardCard.clipsData

                            AudioPlaybackSlot {
                                id: slotItem
                                width: clipsColumn.width
                                
                                required property var modelData
                                required property int index
                                
                                clipId: slotItem.modelData.id || -1
                                clipTitle: slotItem.modelData.title || slotItem.modelData.filePath || "Untitled"
                                hotkeyLabel: slotItem.modelData.hotkey || "F1"

                                onSettingsClicked: {
                                    console.log("Settings clicked for clip:", clipId);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
