import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12
        
        FeatureToggleItem {
            featureName: "Global Hotkeys"
            isEnabled: hotkeyManager ? hotkeyManager.globalHotkeysEnabled : false
            Layout.fillWidth: true
            onEnabledChanged: {
                if (hotkeyManager) {
                    hotkeyManager.globalHotkeysEnabled = isEnabled
                }
            }
        }
        
        FeatureToggleItem {
            featureName: "Equalizer"
            isEnabled: true
            Layout.fillWidth: true
        }
        
        FeatureToggleItem {
            featureName: "Macros"
            isEnabled: true
            Layout.fillWidth: true
        }
        
        FeatureToggleItem {
            featureName: "API Access"
            isEnabled: true
            Layout.fillWidth: true
        }
        
        FeatureToggleItem {
            featureName: "Smart Suggestions"
            isEnabled: true
            Layout.fillWidth: true
        }
        
        Item { Layout.fillHeight: true }
        
        // Save Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Save Changes"
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
