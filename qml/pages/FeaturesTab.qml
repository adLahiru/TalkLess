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
            isEnabled: settingsManager.equalizerEnabled
            Layout.fillWidth: true
            onEnabledChanged: settingsManager.equalizerEnabled = isEnabled
        }
        
        FeatureToggleItem {
            featureName: "Macros"
            isEnabled: settingsManager.macrosEnabled
            Layout.fillWidth: true
            onEnabledChanged: settingsManager.macrosEnabled = isEnabled
        }
        
        FeatureToggleItem {
            featureName: "API Access"
            isEnabled: settingsManager.apiAccessEnabled
            Layout.fillWidth: true
            onEnabledChanged: settingsManager.apiAccessEnabled = isEnabled
        }
        
        FeatureToggleItem {
            featureName: "Smart Suggestions"
            isEnabled: settingsManager.smartSuggestionsEnabled
            Layout.fillWidth: true
            onEnabledChanged: settingsManager.smartSuggestionsEnabled = isEnabled
        }
        
        Item { Layout.fillHeight: true }
        
        // Save Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Save Changes"
                onClicked: settingsManager.saveAllSettings()
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
