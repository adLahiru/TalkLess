pragma Singleton
import QtQuick

QtObject {
    // Font Families
    readonly property string fontFamily: "Segoe UI"
    readonly property string fontFamilyMono: "Consolas"
    
    // Font Sizes
    readonly property int fontSizeXXL: 32
    readonly property int fontSizeXL: 24
    readonly property int fontSizeLarge: 20
    readonly property int fontSizeMedium: 16
    readonly property int fontSizeNormal: 14
    readonly property int fontSizeSmall: 13
    readonly property int fontSizeXSmall: 12
    readonly property int fontSizeTiny: 10
    
    // Font Weights
    readonly property int fontWeightLight: Font.Light
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightBold: Font.Bold
    
    // Line Heights (multipliers)
    readonly property real lineHeightTight: 1.2
    readonly property real lineHeightNormal: 1.5
    readonly property real lineHeightRelaxed: 1.75
    
    // Letter Spacing
    readonly property real letterSpacingTight: -0.5
    readonly property real letterSpacingNormal: 0
    readonly property real letterSpacingWide: 0.5
}
