import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: root
    
    property int currentIndex: 0  // Soundboard selected by default
    property string renamingSectionId: ""
    
    // Persistent settings storage
    Settings {
        id: sidebarSettings
        category: "Sidebar"
        property alias currentIndex: root.currentIndex
    }
    
    width: 250
    color: "#0a0a0f"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        
        // Logo
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            spacing: 10
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: "#06B6D4"
                
                Text {
                    anchors.centerIn: parent
                    text: "◎"
                    font.pixelSize: 20
                    color: "white"
                }
            }
            
            Text {
                text: "Talkless"
                font.pixelSize: 20
                font.weight: Font.Bold
                color: "#06B6D4"
            }
        }
        
        // Menu Items
        SidebarItem {
            icon: "🎛️"
            text: "Soundboard"
            isActive: currentIndex === 0
            onClicked: currentIndex = 0
        }
        
        SidebarItem {
            icon: "🔊"
            text: "Audio Playback Engine"
            isActive: currentIndex === 1
            onClicked: currentIndex = 1
        }
        
        SidebarItem {
            icon: "⚡"
            text: "Macros & Automation"
            isActive: currentIndex === 2
            onClicked: currentIndex = 2
        }
        
        SidebarItem {
            icon: "⚙️"
            text: "Application Settings"
            isActive: currentIndex === 3
            onClicked: currentIndex = 3
        }
        
        SidebarItem {
            icon: "📊"
            text: "Statistics & Reporting"
            isActive: currentIndex === 4
            onClicked: currentIndex = 4
        }
        
        Item { Layout.fillHeight: true }
        
        // Soundboard List
        Text {
            text: "Soundboards"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: "#6B7280"
            Layout.leftMargin: 8
        }
        
        // Soundboard thumbnails
        Repeater {
            id: sectionsRepeater
            model: soundboardView ? soundboardView.sections : []
            
            Rectangle {
                id: sectionItem
                
                required property var modelData
                required property int index
                
                property bool isCurrentSection: soundboardView && soundboardView.currentSection && modelData && modelData.id && soundboardView.currentSection.id === modelData.id
                property bool isActiveSection: soundboardView && soundboardView.activeSection && modelData && modelData.id && soundboardView.activeSection.id === modelData.id
                property bool isRenaming: modelData && renamingSectionId === modelData.id
                
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: isCurrentSection ? "#1a1a2e" : "transparent"
                radius: 8
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    
                    // Radio button for active soundboard selection
                    RadioButton {
                        id: sectionRadio
                        checked: sectionItem.isActiveSection
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            if (soundboardView && sectionItem.modelData) {
                                soundboardView.setActiveSection(sectionItem.modelData.id)
                            }
                        }
                        
                        indicator: Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "transparent"
                            border.color: sectionRadio.checked ? "#7C3AED" : "#6B7280"
                            border.width: 2
                            
                            Rectangle {
                                width: 10
                                height: 10
                                anchors.centerIn: parent
                                radius: 5
                                color: "#7C3AED"
                                visible: sectionRadio.checked
                            }
                        }
                        
                        contentItem: Item { width: 0; height: 0 }
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                    }
                    
                    // Thumbnail
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 6
                        color: "#2a2a3e"
                        clip: true
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#EC4899" }
                                GradientStop { position: 1.0; color: "#F97316" }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🎤"
                                font.pixelSize: 16
                            }
                        }
                    }
                    
                    // Name or rename input
                    TextField {
                        id: renameField
                        visible: sectionItem.isRenaming
                        text: sectionItem.modelData ? sectionItem.modelData.name : ""
                        font.pixelSize: 14
                        color: "white"
                        Layout.fillWidth: true
                        selectByMouse: true
                        background: Rectangle {
                            color: "#2a2a3e"
                            radius: 4
                            border.color: "#7C3AED"
                            border.width: 1
                        }
                        
                        onAccepted: {
                            if (text.trim() !== "" && soundboardView && sectionItem.modelData) {
                                soundboardView.renameSection(sectionItem.modelData.id, text.trim())
                            }
                            renamingSectionId = ""
                        }
                        
                        Keys.onEscapePressed: {
                            renamingSectionId = ""
                        }
                        
                        onVisibleChanged: {
                            if (visible && sectionItem.modelData) {
                                text = sectionItem.modelData.name
                                forceActiveFocus()
                                selectAll()
                            }
                        }
                    }
                    
                    Text {
                        visible: !sectionItem.isRenaming
                        text: sectionItem.modelData ? sectionItem.modelData.name : ""
                        font.pixelSize: 14
                        color: "white"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 30  // Leave space for radio button
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !sectionItem.isRenaming
                    
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (sectionItem.modelData) {
                                sectionContextMenu.sectionId = sectionItem.modelData.id
                                sectionContextMenu.sectionName = sectionItem.modelData.name
                                sectionContextMenu.popup()
                            }
                        } else {
                            if (soundboardView && sectionItem.modelData) {
                                soundboardView.selectSection(sectionItem.modelData.id)
                                currentIndex = 0  // Switch to Soundboard page to show audio clips
                            }
                        }
                    }
                    
                    onEntered: {
                        if (!sectionItem.isCurrentSection) sectionItem.color = "#1a1a2e"
                    }
                    
                    onExited: {
                        if (!sectionItem.isCurrentSection) sectionItem.color = "transparent"
                    }
                }
            }
        }
        
        // Context menu for sections
        Menu {
            id: sectionContextMenu
            property string sectionId: ""
            property string sectionName: ""
            
            background: Rectangle {
                implicitWidth: 160
                color: "#1a1a2e"
                border.color: "#2a2a3e"
                radius: 6
            }
            
            MenuItem {
                text: "Rename"
                icon.source: ""
                onTriggered: {
                    renamingSectionId = sectionContextMenu.sectionId
                }
                background: Rectangle {
                    color: parent.highlighted ? "#2a2a3e" : "transparent"
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    leftPadding: 12
                }
            }
            
            MenuItem {
                text: "Delete"
                enabled: soundboardView && soundboardView.sections && soundboardView.sections.length > 1
                onTriggered: {
                    if (soundboardView) {
                        soundboardView.deleteSection(sectionContextMenu.sectionId)
                    }
                }
                background: Rectangle {
                    color: parent.highlighted ? "#2a2a3e" : "transparent"
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#EF4444" : "#6B7280"
                    font.pixelSize: 13
                    leftPadding: 12
                }
            }
        }
        
        // Add Soundboard Button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: addSoundboardHover.containsMouse ? "#1a1a2e" : "transparent"
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 12
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: "#7C3AED"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "white"
                    }
                }
                
                Text {
                    text: "Add Soundboard"
                    font.pixelSize: 14
                    color: "white"
                }
            }
            
            MouseArea {
                id: addSoundboardHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (soundboardView) {
                        var section = soundboardView.addSection("New Soundboard")
                        if (section) {
                            renamingSectionId = section.id
                        }
                    }
                }
            }
        }
    }
}
