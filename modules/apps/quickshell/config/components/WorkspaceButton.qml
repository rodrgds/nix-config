import QtQuick
import Quickshell.Hyprland
import qs

Rectangle {
    id: root

    required property int workspaceId
    required property string icon
    required property string workspaceName
    required property var barScreen

    readonly property var workspace: {
        const values = Hyprland.workspaces.values;
        for (const candidate of values) {
            if (candidate.id === workspaceId)
                return candidate;
        }
        return null;
    }
    readonly property bool focused: workspace !== null && workspace.focused
    readonly property bool active: workspace !== null && workspace.active
    readonly property bool urgent: workspace !== null && workspace.urgent
    readonly property bool activeHere: active && workspace.monitor === Hyprland.monitorFor(barScreen)
    readonly property int windowCount: workspace === null ? 0 : workspace.toplevels.values.length
    readonly property bool occupied: windowCount > 0

    function activate(): void {
        // Quickshell 0.3's Workspace.activate() still emits the legacy
        // dispatcher syntax, which Hyprland's Lua config rejects.
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + workspaceId + '" })');
    }

    implicitWidth: Math.max(Theme.controlMinWidth, workspaceLabel.implicitWidth + 10)
    implicitHeight: Theme.controlHeight
    color: {
        if (urgent)
            return Theme.bg1;
        if (focused)
            return Theme.orangeBright;
        if (pointer.pressed)
            return Theme.bg2;
        if (active || pointer.containsMouse)
            return Theme.bg1;
        return "transparent";
    }
    border.color: urgent ? Theme.redBright : activeFocus ? Theme.orangeBright : "transparent"
    border.width: 1
    radius: Theme.cornerRadius
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + workspaceId + ", " + workspaceName + (urgent ? ", urgent" : "") + (occupied ? ", " + windowCount + " open windows" : ", empty")
    Accessible.description: urgent ? "Urgent workspace" : focused ? "Focused workspace" : activeHere ? "Visible on this monitor" : active ? "Visible on another monitor" : "Switch workspace"
    Accessible.onPressAction: root.activate()

    Text {
        id: workspaceLabel
        anchors.centerIn: parent
        text: (root.urgent ? "!" : "") + (root.icon !== "" ? root.icon : root.workspaceId)
        color: root.urgent ? Theme.fg0 : root.focused ? Theme.bg0 : root.active ? Theme.fg0 : Theme.fgMuted
        font.family: Theme.primaryFont
        font.pixelSize: Theme.textSize
        renderType: Text.NativeRendering
    }

    Rectangle {
        visible: root.active && !root.urgent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.indicatorHeight
        color: root.focused ? Theme.bg0 : root.activeHere ? Theme.orangeBright : Theme.fgMuted
    }

    Rectangle {
        visible: root.occupied && !root.urgent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 4
        height: 4
        radius: 2
        color: root.focused ? Theme.bg0 : Theme.orangeBright
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            event.accepted = true;
        }
    }

    BarTooltip {
        anchorItem: root
        show: pointer.containsMouse || root.activeFocus
        text: "Workspace " + root.workspaceId + " — " + root.workspaceName + (root.occupied ? " · " + root.windowCount + " open" : " · empty")
    }
}
