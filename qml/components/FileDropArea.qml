// FileDropArea.qml - File upload and drag & drop component
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: root

    // Properties
    property string acceptedFormats: "*.wav *.mp3 *.ogg *.flac *.aac *.m4a"
    property string droppedFilePath: ""
    property string droppedFileName: ""
    property bool hasFile: droppedFilePath !== ""
    property bool isDragHovered: false

    // Signals
    signal fileDropped(string filePath, string fileName)
    signal browseClicked
    signal fileCleared

    color: "transparent"
    radius: 12

    // Dashed border using Canvas
    Canvas {
        id: dashedBorderCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = root.isDragHovered ? "#3B82F6" : "#666666";
            ctx.lineWidth = 2;
            ctx.setLineDash([10, 6]);

            // Draw rounded rectangle
            var radius = 12;
            var x = 1;
            var y = 1;
            var w = width - 2;
            var h = height - 2;

            ctx.beginPath();
            ctx.moveTo(x + radius, y);
            ctx.lineTo(x + w - radius, y);
            ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
            ctx.lineTo(x + w, y + h - radius);
            ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
            ctx.lineTo(x + radius, y + h);
            ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
            ctx.lineTo(x, y + radius);
            ctx.quadraticCurveTo(x, y, x + radius, y);
            ctx.stroke();
        }

        Component.onCompleted: requestPaint()

        Connections {
            target: root
            function onIsDragHoveredChanged() {
                dashedBorderCanvas.requestPaint();
            }
        }
    }

    // Background highlight on hover/drag
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        color: root.isDragHovered ? "#1A3B82F6" : (dropMouseArea.containsMouse ? "#0AFFFFFF" : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // Content - Empty state (no file)
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: !root.hasFile

        // Upload icon using text (arrow up from tray)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            color: "transparent"

            // Upload icon (arrow pointing up with base line)
            Item {
                anchors.centerIn: parent
                width: 28
                height: 28

                // Arrow shaft
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    width: 3
                    height: 14
                    color: root.isDragHovered ? "#3B82F6" : "#888888"
                    radius: 1
                }

                // Arrow head (using Canvas for triangle)
                Canvas {
                    id: arrowHeadCanvas
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    width: 14
                    height: 10

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = root.isDragHovered ? "#3B82F6" : "#888888";
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 0);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                        ctx.closePath();
                        ctx.fill();
                    }

                    Component.onCompleted: requestPaint()

                    Connections {
                        target: root
                        function onIsDragHoveredChanged() {
                            arrowHeadCanvas.requestPaint();
                        }
                    }
                }

                // Base line (tray)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 20
                    height: 3
                    color: root.isDragHovered ? "#3B82F6" : "#888888"
                    radius: 1
                }
            }
        }

        // Drop text
        Text {
            text: "Drop audio files here or click to browse"
            color: root.isDragHovered ? "#AAAAAA" : "#888888"
            font.pixelSize: 12
            font.family: "Arial"
            Layout.alignment: Qt.AlignHCenter

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }

    // Content - File loaded state
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: root.hasFile

        // File icon
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            color: "#3B82F6"
            radius: 8

            Text {
                anchors.centerIn: parent
                text: "♪"
                color: "#FFFFFF"
                font.pixelSize: 20
            }
        }

        // File name
        Text {
            text: root.droppedFileName
            color: "#FFFFFF"
            font.pixelSize: 12
            font.family: "Arial"
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width - 40
            elide: Text.ElideMiddle
        }

        // Clear button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 60
            Layout.preferredHeight: 24
            color: clearBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
            radius: 4

            Text {
                anchors.centerIn: parent
                text: "Clear"
                color: "#FFFFFF"
                font.pixelSize: 11
            }

            MouseArea {
                id: clearBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.droppedFilePath = "";
                    root.droppedFileName = "";
                    root.fileCleared();
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }

    // Drop area for drag & drop
    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]

        onEntered: function (drag) {
            root.isDragHovered = true;
            drag.accepted = true;
        }

        onExited: {
            root.isDragHovered = false;
        }

        onDropped: function (drop) {
            root.isDragHovered = false;
            if (drop.hasUrls && drop.urls.length > 0) {
                var fileUrl = drop.urls[0].toString();
                // Remove file:// prefix if present
                var filePath = fileUrl.replace(/^file:\/\//, "");
                // Extract filename
                var fileName = filePath.split("/").pop();

                root.droppedFilePath = filePath;
                root.droppedFileName = fileName;
                root.fileDropped(filePath, fileName);
            }
        }
    }

    // Mouse area for click to browse
    MouseArea {
        id: dropMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            fileDialog.open();
        }
    }

    // File dialog for browsing
    FileDialog {
        id: fileDialog
        title: "Select Audio File"
        nameFilters: ["Audio files (*.wav *.mp3 *.ogg *.flac *.aac *.m4a)", "All files (*)"]

        onAccepted: {
            if (selectedFile) {
                var fileUrl = selectedFile.toString();
                var filePath = fileUrl.replace(/^file:\/\//, "");
                var fileName = filePath.split("/").pop();

                root.droppedFilePath = filePath;
                root.droppedFileName = fileName;
                root.fileDropped(filePath, fileName);
            }
        }
    }
}
