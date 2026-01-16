pragma Singleton
import QtQuick

QtObject {
    // Spacing
    readonly property int spacingXXS: 4
    readonly property int spacingXS: 8
    readonly property int spacingSmall: 12
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 20
    readonly property int spacingXL: 24
    readonly property int spacingXXL: 32
    readonly property int spacingHuge: 48
    
    // Border Radius
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12
    readonly property int radiusXL: 16
    readonly property int radiusRound: 999
    
    // Border Width
    readonly property int borderThin: 1
    readonly property int borderMedium: 2
    readonly property int borderThick: 3
    
    // Shadows
    readonly property int shadowSmall: 2
    readonly property int shadowMedium: 4
    readonly property int shadowLarge: 8
    
    // Animation Durations (ms)
    readonly property int durationFast: 150
    readonly property int durationNormal: 200
    readonly property int durationSlow: 300
    
    // Component Sizes
    readonly property int buttonHeightSmall: 32
    readonly property int buttonHeightMedium: 40
    readonly property int buttonHeightLarge: 48
    
    readonly property int inputHeight: 40
    readonly property int sidebarWidth: 250
    readonly property int headerHeight: 60
    
    // Z-Index Layers
    readonly property int zIndexBase: 0
    readonly property int zIndexDropdown: 100
    readonly property int zIndexModal: 200
    readonly property int zIndexTooltip: 300
}
