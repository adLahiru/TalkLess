import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

Rectangle {
    id: root
    color: Colors.background
    radius: 10

    // Properties for dynamic banner text
    property string bannerMainText: "Statistics & Reporting (Enterprise)"
    property string bannerSecondaryText: "For power users, team leads, or admins."

    // Mock data for demonstration
    property int totalPlays: 1842
    property string totalDuration: "125h 34m"
    property int activeSlots: 74
    property string timeSavedEstimate: "88 hrs"
    property bool trainingModeEnabled: false
    property bool apiAccessEnabled: true
    property string apiKey: "sk-••••••••••••••••"

    // Mock usage logs
    property var usageLogs: [
        { date: "7/12", agent: "sara", slot: "#25", time: "4m" },
        { date: "7/10", agent: "Sara", slot: "#23", time: "4m" }
    ]

    // Mock agents
    property var agents: [
        { name: "Agent 1", checked: true, color: Colors.accent },
        { name: "Agent 2", checked: true, color: "#9b59b6" },
        { name: "Agent 3", checked: true, color: "#3498db" }
    ]

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainContent.height + 40
        clip: true

        ColumnLayout {
            id: mainContent
            width: parent.width
            spacing: 20

            // Background Banner at the top
            BackgroundBanner {
                id: banner
                Layout.fillWidth: true
                Layout.preferredHeight: 145
                displayText: root.bannerMainText + "," + root.bannerSecondaryText
            }

            // Main content with padding
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 24

                // REST API Access Section
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: Colors.panelBg
                    radius: 12

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Text {
                            text: "🔐"
                            font.pixelSize: 18
                        }

                        Text {
                            text: "REST API Access (Enterprise Only)"
                            color: Colors.textPrimary
                            font.pixelSize: Typography.fontSizeMedium
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        // API Docs Button
                        Rectangle {
                            width: 90
                            height: 32
                            radius: 8
                            color: Colors.surface
                            border.color: Colors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "📄"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "API Docs"
                                    color: Colors.textPrimary
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("API Docs clicked")
                            }
                        }
                    }
                }

                // API Key Row
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: Colors.surface
                    radius: 10
                    border.color: Colors.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "API Key:"
                            color: Colors.textSecondary
                            font.pixelSize: 14
                        }

                        Text {
                            text: root.apiKey
                            color: Colors.textPrimary
                            font.pixelSize: 14
                            font.family: "monospace"
                        }

                        Item { Layout.fillWidth: true }

                        // Copy button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: copyMouse.containsMouse ? Colors.surfaceLight : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "📋"
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: copyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Copy API key")
                            }
                        }

                        // Toggle
                        Rectangle {
                            width: 44
                            height: 24
                            radius: 12
                            color: root.apiAccessEnabled ? Colors.success : Colors.surfaceLight

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: Colors.textPrimary
                                x: root.apiAccessEnabled ? parent.width - width - 3 : 3
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on x { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.apiAccessEnabled = !root.apiAccessEnabled
                            }
                        }
                    }
                }

                // API Log Section
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: Colors.panelBg
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: "API Log"
                            color: Colors.textSecondary
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Log entries
                        Repeater {
                            model: [
                                { time: "09:00 AM", event: "Play Macro 'X'" },
                                { time: "01:00 AM", event: "Stopped Macro 'Intro'" }
                            ]

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // Time badge
                                Rectangle {
                                    width: 100
                                    height: 28
                                    radius: 14
                                    color: Colors.surface
                                    border.color: Colors.border

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "🕐"
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            text: modelData.time
                                            color: Colors.textPrimary
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                // Timeline line
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 2
                                    color: Colors.border
                                }

                                // Event badge
                                Rectangle {
                                    width: 160
                                    height: 28
                                    radius: 6
                                    color: index === 0 ? Colors.accent : Colors.success

                                    Text {
                                        anchors.centerIn: parent
                                        text: (index === 0 ? "▶ " : "✓ ") + modelData.event
                                        color: Colors.textOnAccent
                                        font.pixelSize: 12
                                    }
                                }

                                required property int index
                                required property var modelData
                            }
                        }
                    }
                }

                // Overview Section
                Text {
                    text: "Overview"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeLarge
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: Colors.panelBg
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        // Stats rows
                        Repeater {
                            model: [
                                { label: "Total Plays:", value: root.totalPlays.toString() },
                                { label: "Total Duration:", value: root.totalDuration },
                                { label: "Active Slots:", value: root.activeSlots.toString() },
                                { label: "Time Saved Estimate:", value: root.timeSavedEstimate }
                            ]

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: modelData.label
                                    color: Colors.textSecondary
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: modelData.value
                                    color: Colors.textPrimary
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }

                                required property var modelData
                            }
                        }
                    }
                }

                // Training Mode Toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Training Mode"
                        color: Colors.textPrimary
                        font.pixelSize: Typography.fontSizeMedium
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        width: 52
                        height: 28
                        radius: 14
                        color: root.trainingModeEnabled ? Colors.success : Colors.surfaceLight

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: root.trainingModeEnabled ? Colors.textPrimary : Colors.border
                            x: root.trainingModeEnabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on x { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.trainingModeEnabled = !root.trainingModeEnabled
                        }
                    }
                }

                // Agent Filter Section
                Text {
                    text: "Agent Filter in Reporting"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Enable this feature to filter reports based on individual or multiple agents. It helps admins assess agent-wise performance metrics like usage, duration, and time saved."
                    color: Colors.textSecondary
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: Colors.panelBg
                    radius: 12

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 20

                        // Agent checkboxes
                        ColumnLayout {
                            spacing: 8

                            Text {
                                text: "Compare agents"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                            }

                            Repeater {
                                model: root.agents

                                RowLayout {
                                    spacing: 8

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 4
                                        color: modelData.checked ? modelData.color : "transparent"
                                        border.width: 2
                                        border.color: modelData.color

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.checked ? "✓" : ""
                                            color: Colors.white
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var newAgents = root.agents.slice();
                                                newAgents[index].checked = !newAgents[index].checked;
                                                root.agents = newAgents;
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.name
                                        color: Colors.textPrimary
                                        font.pixelSize: 13
                                    }

                                    required property var modelData
                                    required property int index
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Agent dropdown
                        ColumnLayout {
                            spacing: 8

                            Text {
                                text: "Select Agent"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                            }

                            Rectangle {
                                width: 160
                                height: 36
                                radius: 8
                                color: Colors.surface
                                border.color: Colors.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10

                                    Text {
                                        text: "Choose agent"
                                        color: Colors.textSecondary
                                        font.pixelSize: 13
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "▼"
                                        color: Colors.textSecondary
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }

                // Charts Section
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250
                    spacing: 20

                    // Line Chart - Usage over Time
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Colors.panelBg
                        radius: 12

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Viewing metrics for: Agent 1"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Simple line chart placeholder
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Placeholder chart with rectangles
                                Row {
                                    anchors.fill: parent
                                    anchors.bottomMargin: 10
                                    spacing: 4

                                    Repeater {
                                        model: [60, 40, 80, 30, 70, 50, 60, 40, 55]

                                        Rectangle {
                                            width: (parent.width - 8 * 4) / 9
                                            height: parent.height * (modelData / 100)
                                            anchors.bottom: parent.bottom
                                            color: Colors.accent
                                            radius: 2

                                            required property var modelData
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Usage over Time"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Bar Chart - Agent-wise Usage
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Colors.panelBg
                        radius: 12

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Item { Layout.preferredHeight: 20 }

                            // Bar chart placeholder
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Row {
                                    anchors.fill: parent
                                    anchors.bottomMargin: 10
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            [80, 60, 40],
                                            [50, 30, 70],
                                            [90, 50, 60],
                                            [40, 80, 50],
                                            [70, 40, 80],
                                            [60, 70, 40],
                                            [80, 50, 60],
                                            [50, 90, 70]
                                        ]

                                        Row {
                                            spacing: 2
                                            anchors.bottom: parent.bottom

                                            Rectangle {
                                                width: 8
                                                height: parent.parent.parent.height * (modelData[0] / 100)
                                                color: Colors.accent
                                                anchors.bottom: parent.bottom
                                            }
                                            Rectangle {
                                                width: 8
                                                height: parent.parent.parent.height * (modelData[1] / 100)
                                                color: "#9b59b6"
                                                anchors.bottom: parent.bottom
                                            }
                                            Rectangle {
                                                width: 8
                                                height: parent.parent.parent.height * (modelData[2] / 100)
                                                color: "#3498db"
                                                anchors.bottom: parent.bottom
                                            }

                                            required property var modelData
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Agent-wise Usage Bar"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Usage Logs Section
                Text {
                    text: "Usage Logs"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: Colors.panelBg
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 0

                        // Header row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32

                            Text {
                                text: "Date"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: "Agent"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: "Slot"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: "Time"
                                color: Colors.textSecondary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                        }

                        // Data rows
                        Repeater {
                            model: root.usageLogs

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32

                                Text {
                                    text: modelData.date
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 100
                                }

                                Text {
                                    text: modelData.agent
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 100
                                }

                                Text {
                                    text: modelData.slot
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 100
                                }

                                Text {
                                    text: modelData.time
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                required property var modelData
                            }
                        }
                    }
                }

                // Export Data Section
                Text {
                    text: "Export Data"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: Colors.panelBg
                    radius: 12

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        // Export CSV Button
                        Rectangle {
                            width: 120
                            height: 36
                            radius: 8
                            color: Colors.surface
                            border.color: Colors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "📄"
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: "Export CSV"
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Export CSV clicked")
                            }
                        }

                        // Export JSON Button
                        Rectangle {
                            width: 120
                            height: 36
                            radius: 8
                            color: Colors.surface
                            border.color: Colors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "📄"
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: "Export JSON"
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Export JSON clicked")
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // API Activity Section
                Text {
                    text: "API Activity"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Colors.panelBg
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 4
                                color: Colors.success

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Colors.white
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: "API Hits: 12,030 this month"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 4
                                color: Colors.success

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Colors.white
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: "Average response: 180ms"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // Feature Access Section
                Text {
                    text: "Feature Access"
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: Colors.panelBg
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "Dashboard Access", checked: true },
                                { label: "API Reporting", checked: true },
                                { label: "Per-Agent Data", checked: true }
                            ]

                            RowLayout {
                                spacing: 8

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 4
                                    color: modelData.checked ? Colors.success : "transparent"
                                    border.width: 2
                                    border.color: Colors.success

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.checked ? "✓" : ""
                                        color: Colors.white
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    text: modelData.label
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                }

                                required property var modelData
                            }
                        }
                    }
                }

                // Bottom spacing
                Item {
                    Layout.preferredHeight: 20
                }
            }
        }
    }
}
