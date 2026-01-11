pragma Singleton
import QtQuick

QtObject {
    // Theme property
    property string currentTheme: "dark"

    // Primary Colors (Driven by Accent)
    property color accent: "#7C3AED" // Default purple
    property color primary: accent
    property color primaryDark: Qt.darker(accent, 1.3)
    property color primaryLight: Qt.lighter(accent, 1.3)
    property color textOnPrimary: "#FFFFFF"

    // Secondary & Functional Colors
    property color secondary: "#EC4899"
    property color success: currentTheme === "light" ? "#10B981" : "#22C55E"
    property color warning: "#F59E0B"
    property color error: "#EF4444"
    property color errorDark: Qt.darker(error, 1.2)
    property color errorLight: Qt.lighter(error, 1.2)
    property color info: "#3B82F6"

    // Backgrounds - Modern Glassmorphism & High-Contrast
    property color background: currentTheme === "light" ? "#F1F5F9" : "#0A0A0B"
    property color backgroundDark: currentTheme === "light" ? "#E2E8F0" : "#050506"
    property color surface: currentTheme === "light" ? "#FFFFFF" : "#121214"
    property color surfaceLight: currentTheme === "light" ? "#FDFDFD" : "#1C1C1E"
    property color surfaceDark: currentTheme === "light" ? "#CBD5E1" : "#080809"

    // Panel & Card Colors
    property color panelBg: currentTheme === "light" ? "#FFFFFF" : "#141416"
    property color cardBg: currentTheme === "light" ? "#FFFFFF" : "#1A1A1C"

    // Text Colors - Neutral Zinc Palette
    property color textPrimary: currentTheme === "light" ? "#0F172A" : "#F8FAFC"
    property color textSecondary: currentTheme === "light" ? "#475569" : "#94A3B8"
    property color textTertiary: currentTheme === "light" ? "#64748B" : "#64748B"
    property color textDisabled: currentTheme === "light" ? "#94A3B8" : "#334155"

    // Borders - Subtle & Refined
    property color border: currentTheme === "light" ? "#E2E8F0" : "#27272A"
    property color borderLight: currentTheme === "light" ? "#F1F5F9" : "#3F3F46"
    property color borderDark: currentTheme === "light" ? "#CBD5E1" : "#18181B"

    // Assets
    property url bannerImage: currentTheme === "light" ? "qrc:/qt/qml/TalkLess/resources/images/background_light.png" : "qrc:/qt/qml/TalkLess/resources/images/background.png"
    property url splashImage: currentTheme === "light" ? "qrc:/qt/qml/TalkLess/resources/images/Splash_Screen_light.png" : "qrc:/qt/qml/TalkLess/resources/images/splashScreen.png"

    // Special Tokens
    property color shadow: currentTheme === "light" ? "rgba(0,0,0,0.06)" : "rgba(0,0,0,0.4)"
    property color overlay: currentTheme === "light" ? "rgba(0,0,0,0.02)" : "rgba(255,255,255,0.02)"
    property color white: "#FFFFFF"
    property color black: "#000000"

    // Gradients - Premium Look
    property color gradientPrimaryStart: accent
    property color gradientPrimaryEnd: Qt.lighter(accent, 1.5)
    property color gradientBgStart: currentTheme === "light" ? "#F8FAFC" : "#0C0C0E"
    property color gradientBgEnd: currentTheme === "light" ? "#F1F5F9" : "#141416"

    // Logic: Self-Update from Service
    function setTheme(theme) {
        if (!theme)
            return;
        let t = theme.toLowerCase();
        if (t === "light" || t === "dark") {
            currentTheme = t;
        } else {
            currentTheme = "dark";
        }
    }

    function setAccentColor(color) {
        if (color && color.length >= 4) {
            accent = color;
        }
    }

    readonly property Connections _serviceConnections: Connections {
        target: typeof soundboardService !== "undefined" ? soundboardService : null
        function onSettingsChanged() {
            setTheme(soundboardService.theme);
            setAccentColor(soundboardService.accentColor);
        }
    }

    Component.onCompleted: {
        if (typeof soundboardService !== "undefined") {
            setTheme(soundboardService.theme);
            setAccentColor(soundboardService.accentColor);
        }
    }
}
