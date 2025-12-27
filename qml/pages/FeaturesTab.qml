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
            isEnabled: hotkeyManager ? hotkeyManager.globalHotkeysEnabled : true
            Layout.fillWidth: true
            onEnabledChanged: function(enabled) {
                if (hotkeyManager) {
                    hotkeyManager.globalHotkeysEnabled = enabled
                }
            }
        }
        
        FeatureToggleItem {
            featureName: "Equalizer"
            isEnabled: settingsManager.equalizerEnabled
            Layout.fillWidth: true
            onEnabledChanged: function(enabled) { settingsManager.equalizerEnabled = enabled }
        }
        
        FeatureToggleItem {
            featureName: "Macros"
            isEnabled: settingsManager.macrosEnabled
            Layout.fillWidth: true
            onEnabledChanged: function(enabled) { settingsManager.macrosEnabled = enabled }
        }
        
        FeatureToggleItem {
            featureName: "API Access"
            isEnabled: settingsManager.apiAccessEnabled
            Layout.fillWidth: true
            onEnabledChanged: function(enabled) { settingsManager.apiAccessEnabled = enabled }
        }
        
        FeatureToggleItem {
            featureName: "Smart Suggestions"
            isEnabled: settingsManager.smartSuggestionsEnabled
            Layout.fillWidth: true
            onEnabledChanged: function(enabled) { settingsManager.smartSuggestionsEnabled = enabled }
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
