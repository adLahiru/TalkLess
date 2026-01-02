import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property int currentTabIndex: 0
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Settings Header with background image
        SettingsHeader {
            Layout.fillWidth: true
            title: "System Settings"
            subtitle: "Manage subscription plans, quotas, and billing details."
            backgroundImage: "qrc:/qt/qml/TalkLess/resources/images/background-52.png"
        }
        
        // Tab Bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            Layout.topMargin: -25
            
            SettingsTabBar {
                id: tabBar
                anchors.centerIn: parent
                currentIndex: currentTabIndex
                tabs: ["Audio Devices", "Volume Mixer", "Hotkeys", "Features", "UI & Display", "Updates"]
                onTabClicked: function(index) {
                    currentTabIndex = index
                }
            }
        }
        
        // Tab Content
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTabIndex
            
            AudioDevicesTab {}
            VolumeMixerPage {}
            HotkeysTab {}
            FeaturesTab {}
            UIDisplayTab {}
            UpdatesTab {}
        }
    }
}
