pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    property int dotCount: 10
    property int activeDots: 3   // how many should be green
    property int dotSize: 6
    property int gap: 4

    implicitWidth: dotCount * dotSize + (dotCount - 1) * gap
    implicitHeight: dotSize

    Row {
        spacing: root.gap

        Repeater {
            model: root.dotCount
            delegate: Rectangle {
                required property int index
                width: root.dotSize
                height: root.dotSize
                radius: root.dotSize / 2

                // Green for active, grey/white for inactive
                color: (index < root.activeDots) ? "#2DFF6A" : "#D9D9D9"
                opacity: (index < root.activeDots) ? 1.0 : 0.6
            }
        }
    }
}
