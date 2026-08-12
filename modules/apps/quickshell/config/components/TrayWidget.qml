import QtQuick
import Quickshell.Services.SystemTray
import qs

Item {
    id: root

    implicitWidth: trayItems.implicitWidth
    implicitHeight: Theme.controlHeight
    visible: SystemTray.items.values.length > 0

    Row {
        id: trayItems
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: SystemTray.items

            TrayItem {
                required property var modelData
                item: modelData
            }
        }
    }
}
