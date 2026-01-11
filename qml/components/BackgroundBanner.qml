// BackgroundBanner.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // Pass comma-separated text like "Line 1,Line 2" or empty string for no text
    property string displayText: ""

    // Computed properties for the two lines
    readonly property var textLines: displayText.length > 0 ? displayText.split(",") : []
    readonly property string line1: textLines.length > 0 ? textLines[0].trim() : ""
    readonly property string line2: textLines.length > 1 ? textLines[1].trim() : ""
    readonly property bool hasText: displayText.length > 0

    // Default size - can be overridden by parent
    implicitWidth: 400
    implicitHeight: 200
    radius: 16
    clip: true
    color: backgroundImage.status === Image.Error ? "red" : (backgroundImage.status === Image.Loading ? "blue" : "transparent")

    // Load Poppins font (SemiBold 600)
    FontLoader {
        id: poppinsFont
        source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLEj6Z1JlFc-K.ttf"
    }

    // Load Inter font (Regular 400)
    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Background image
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: Colors.bannerImage
        fillMode: Image.Stretch

        onStatusChanged: {
            if (status === Image.Error) {
                console.log("BackgroundBanner Image Error loading: " + source);
            } else if (status === Image.Ready) {
                console.log("BackgroundBanner Image Loaded: " + source);
            }
        }
    }

    // Dark overlay for better text readability (only when text is shown)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colors.black
        opacity: root.hasText ? 0.4 : 0
        visible: root.hasText

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // Text container (only visible when there's text)
    ColumnLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 30
        spacing: 4
        visible: root.hasText
        opacity: root.hasText ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        // Line 1 - Main text (Poppins SemiBold 27.51px)
        Text {
            text: root.line1
            color: Colors.textPrimary
            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignLeft
            visible: root.line1.length > 0
        }

        // Line 2 - Secondary text (Inter Regular 15.29px)
        Text {
            text: root.line2
            color: "#FFFFFF"
            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
            font.pixelSize: 15
            font.weight: Font.Normal
            Layout.alignment: Qt.AlignLeft
            visible: root.line2.length > 0
        }
    }
}
