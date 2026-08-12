import QtQuick
import qs

Item {
    id: root

    required property var barScreen

    implicitWidth: workspaces.implicitWidth
    implicitHeight: Theme.controlHeight

    Row {
        id: workspaces
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: Theme.workspaceSpecs

            WorkspaceButton {
                required property var modelData
                workspaceId: modelData.id
                icon: modelData.icon
                workspaceName: modelData.name
                barScreen: root.barScreen
            }
        }
    }
}
