import QtQuick
import qs

Item {
    id: root

    required property string title
    required property string value
    required property real progress
    property color accent: Theme.orangeBright
    property string tooltipText: title + " " + value

    implicitWidth: labels.implicitWidth + 10
    implicitHeight: Theme.controlHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: tooltipText

    Row {
        id: labels
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.title
            color: Theme.fgMuted
            font.family: Theme.primaryFont
            font.pixelSize: Theme.textSize
            renderType: Text.NativeRendering
        }

        Text {
            text: root.value
            color: Theme.fg0
            font.family: Theme.primaryFont
            font.pixelSize: Theme.textSize
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        height: Theme.indicatorHeight
        color: root.accent
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }

    BarTooltip {
        anchorItem: root
        show: pointer.containsMouse
        text: root.tooltipText
    }
}
