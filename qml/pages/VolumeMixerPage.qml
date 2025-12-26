import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TalkLess 1.0

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 24

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        Text {
            text: "Volume Mixer"
            font.pixelSize: 22
            font.bold: true
            color: "white"
        }

        // Single card container
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#26293a"
            radius: 12
            border.color: "#3f3f46"
            border.width: 1
            anchors.margins: 24

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 32

                // Master volume
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Master Volume"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Slider {
                            id: masterSlider
                            Layout.fillWidth: true
                            from: -60.0
                            to: 20.0
                            value: audioManager ? Functions.linearToDb(audioManager.masterVolume()) : 0.0
                            onValueChanged: {
                                if (audioManager) audioManager.setMasterVolume(Functions.dbToLinear(value))
                            }
                            background: Rectangle {
                                implicitWidth: 200
                                implicitHeight: 6
                                width: masterSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: "#3f3f46"
                                Rectangle {
                                    width: masterSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: "#7C3AED"
                                }
                            }
                            handle: Rectangle {
                                x: masterSlider.leftPadding + masterSlider.visualPosition * (masterSlider.availableWidth - width)
                                y: masterSlider.topPadding + masterSlider.availableHeight / 2 - height / 2
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: "#7C3AED"
                                border.color: "#ffffff"
                                border.width: 2
                            }
                        }

                        Text {
                            text: Functions.formatDb(masterSlider.value)
                            font.pixelSize: 14
                            color: "#d1d5db"
                            Layout.minimumWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Microphone volume
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Microphone Gain"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Slider {
                            id: micSlider
                            Layout.fillWidth: true
                            from: -20.0  // -20dB to +6dB (200% boost)
                            to: 6.0
                            value: audioManager ? Functions.linearToDb(audioManager.micVolume()) : 0.0
                            onValueChanged: {
                                if (audioManager) audioManager.setMicVolume(Functions.dbToLinear(value))
                            }
                            background: Rectangle {
                                implicitWidth: 200
                                implicitHeight: 6
                                width: micSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: "#3f3f46"
                                Rectangle {
                                    width: micSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: "#7C3AED"
                                }
                            }
                            handle: Rectangle {
                                x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                                y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: "#7C3AED"
                                border.color: "#ffffff"
                                border.width: 2
                            }
                        }

                        Text {
                            text: Functions.formatDb(micSlider.value)
                            font.pixelSize: 14
                            color: "#d1d5db"
                            Layout.minimumWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        text: "Mic slider range: -20dB to +6dB (200% boost)"
                        font.pixelSize: 12
                        color: "#9CA3AF"
                        Layout.topMargin: 4
                    }
                }

                // Current clip volume
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Clip Volume"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                    }

                    Text {
                        text: (audioManager && audioManager.currentClip) ? audioManager.currentClip.title || "Untitled Clip" : "No clip playing"
                        font.pixelSize: 14
                        color: "#d1d5db"
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Slider {
                            id: currentClipSlider
                            Layout.fillWidth: true
                            from: -60.0
                            to: 20.0
                            enabled: audioManager && audioManager.currentClip !== null
                            value: (audioManager && audioManager.currentClip) ? Functions.linearToDb(audioManager.currentClip.volume) : 0.0
                            onValueChanged: {
                                if (audioManager && audioManager.currentClip && audioManager.currentClip.volume !== Functions.dbToLinear(value)) {
                                    audioManager.currentClip.volume = Functions.dbToLinear(value)
                                    audioManager.setClipVolume(audioManager.currentClip.id, Functions.dbToLinear(value))
                                }
                            }
                            background: Rectangle {
                                implicitWidth: 200
                                implicitHeight: 6
                                width: currentClipSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: "#3f3f46"
                                Rectangle {
                                    width: currentClipSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: "#7C3AED"
                                }
                            }
                            handle: Rectangle {
                                x: currentClipSlider.leftPadding + currentClipSlider.visualPosition * (currentClipSlider.availableWidth - width)
                                y: currentClipSlider.topPadding + currentClipSlider.availableHeight / 2 - height / 2
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: "#7C3AED"
                                border.color: "#ffffff"
                                border.width: 2
                            }
                        }

                        Text {
                            text: Functions.formatDb(currentClipSlider.value)
                            font.pixelSize: 14
                            color: "#d1d5db"
                            Layout.minimumWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        visible: !(audioManager && audioManager.currentClip)
                        text: "Play a clip to control its volume here."
                        font.pixelSize: 12
                        color: "#9CA3AF"
                        Layout.topMargin: 4
                    }
                }

                Item { Layout.fillHeight: true } // spacer
            }
        }
    }
}
