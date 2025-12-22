pragma Singleton
import QtQuick

QtObject {
    // Primary Colors
    readonly property color primary: "#7C3AED"
    readonly property color primaryDark: "#6D28D9"
    readonly property color primaryLight: "#A78BFA"
    
    // Secondary Colors
    readonly property color secondary: "#EC4899"
    readonly property color cyan: "#06B6D4"
    readonly property color green: "#22C55E"
    
    // Background Colors
    readonly property color background: "#0f0f1a"
    readonly property color backgroundDark: "#0a0a0f"
    readonly property color surface: "#1a1a2e"
    readonly property color surfaceLight: "#2a2a3e"
    readonly property color surfaceDark: "#12121a"
    
    // Text Colors
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#9CA3AF"
    readonly property color textTertiary: "#6B7280"
    readonly property color textDisabled: "#4B5563"
    
    // State Colors
    readonly property color success: "#22C55E"
    readonly property color warning: "#F59E0B"
    readonly property color error: "#EF4444"
    readonly property color info: "#3B82F6"
    
    // Border Colors
    readonly property color border: "#2a2a3e"
    readonly property color borderLight: "#374151"
    readonly property color borderDark: "#1a1a2e"
    
    // Overlay Colors
    readonly property color overlay: "#000000"
    readonly property real overlayOpacity: 0.5
    
    // Gradient colors
    readonly property color gradientPrimaryStart: "#9333EA"
    readonly property color gradientPrimaryEnd: "#EC4899"
    readonly property color gradientBgStart: "#1a0a2e"
    readonly property color gradientBgEnd: "#2a1040"
}
