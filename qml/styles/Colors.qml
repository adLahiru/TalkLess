pragma Singleton
import QtQuick

QtObject {
    // Theme property
    property string currentTheme: "dark"
    
    // Primary Colors
    property color primary: currentTheme === "light" ? "#6366F1" : "#7C3AED"
    property color primaryDark: currentTheme === "light" ? "#4F46E5" : "#6D28D9"
    property color primaryLight: currentTheme === "light" ? "#818CF8" : "#A78BFA"
    
    // Secondary Colors
    property color secondary: currentTheme === "light" ? "#EC4899" : "#EC4899"
    property color cyan: currentTheme === "light" ? "#06B6D4" : "#06B6D4"
    property color green: currentTheme === "light" ? "#10B981" : "#22C55E"
    
    // Background Colors
    property color background: currentTheme === "light" ? "#FFFFFF" : "#0f0f1a"
    property color backgroundDark: currentTheme === "light" ? "#F9FAFB" : "#0a0a0f"
    property color surface: currentTheme === "light" ? "#F3F4F6" : "#1a1a2e"
    property color surfaceLight: currentTheme === "light" ? "#E5E7EB" : "#2a2a3e"
    property color surfaceDark: currentTheme === "light" ? "#D1D5DB" : "#12121a"
    
    // Text Colors
    property color textPrimary: currentTheme === "light" ? "#111827" : "#FFFFFF"
    property color textSecondary: currentTheme === "light" ? "#6B7280" : "#9CA3AF"
    property color textTertiary: currentTheme === "light" ? "#9CA3AF" : "#6B7280"
    property color textDisabled: currentTheme === "light" ? "#D1D5DB" : "#4B5563"
    
    // State Colors
    property color success: currentTheme === "light" ? "#10B981" : "#22C55E"
    property color warning: currentTheme === "light" ? "#F59E0B" : "#F59E0B"
    property color error: currentTheme === "light" ? "#EF4444" : "#EF4444"
    property color info: currentTheme === "light" ? "#3B82F6" : "#3B82F6"
    
    // Border Colors
    property color border: currentTheme === "light" ? "#E5E7EB" : "#2a2a3e"
    property color borderLight: currentTheme === "light" ? "#F3F4F6" : "#374151"
    property color borderDark: currentTheme === "light" ? "#D1D5DB" : "#1a1a2e"
    
    // Overlay Colors
    property color overlay: currentTheme === "light" ? "#000000" : "#000000"
    property real overlayOpacity: currentTheme === "light" ? 0.3 : 0.5
    
    // Gradient colors
    property color gradientPrimaryStart: currentTheme === "light" ? "#6366F1" : "#9333EA"
    property color gradientPrimaryEnd: currentTheme === "light" ? "#EC4899" : "#EC4899"
    property color gradientBgStart: currentTheme === "light" ? "#F9FAFB" : "#1a0a2e"
    property color gradientBgEnd: currentTheme === "light" ? "#F3F4F6" : "#2a1040"
    
    // Theme switching function
    function setTheme(theme) {
        currentTheme = theme
    }
}
