import QtQuick
import qs
import qs.services

Item {
    id: root

    implicitWidth: clockLabel.implicitWidth + 10
    implicitHeight: Theme.controlHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: Time.full

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: Time.compact
        color: Theme.fg0
        font.family: Theme.primaryFont
        font.pixelSize: Theme.textSize
        renderType: Text.NativeRendering
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
        text: Time.full
    }
}
