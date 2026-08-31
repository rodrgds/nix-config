import QtQuick
import Quickshell.Hyprland
import qs
import qs.services

Rectangle {
    id: root

    required property var barScreen

    readonly property var workspace: {
        const workspaces = Hyprland.workspaces.values;
        for (const candidate of workspaces) {
            if (candidate.name === "special:music")
                return candidate;
        }
        return null;
    }
    readonly property bool openHere: workspace !== null && workspace.active && workspace.monitor === Hyprland.monitorFor(barScreen)
    readonly property int windowCount: workspace === null ? 0 : workspace.toplevels.values.length
    readonly property bool occupied: windowCount > 0
    readonly property bool hovered: pointer.containsMouse

    function toggleScratchpad(): void {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special('music')");
    }

    implicitWidth: Math.min(360, Math.max(Theme.controlMinWidth, content.implicitWidth + 12))
    implicitHeight: Theme.controlHeight
    color: {
        if (pointer.pressed)
            return Theme.orangeBright;
        if (root.openHere || root.hovered)
            return Theme.bg1;
        return "transparent";
    }
    border.color: activeFocus ? Theme.orangeBright : "transparent"
    border.width: 1
    radius: Theme.cornerRadius
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: "Music scratchpad" + (root.occupied ? ", " + root.windowCount + " open windows" : ", empty") + (Media.available ? ", " + Media.nowPlaying : "")
    Accessible.description: root.openHere ? "Hide the music scratchpad" : "Show the music scratchpad"
    Accessible.onPressAction: root.toggleScratchpad()

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Media.available ? 6 : 0

        Text {
            text: Media.playing ? "\uf04b" : "\uf001"
            color: pointer.pressed ? Theme.bg0 : root.openHere ? Theme.orangeBright : Theme.fg0
            font.family: Theme.monoFont
            font.pixelSize: Theme.textSize
            renderType: Text.NativeRendering
        }

        Text {
            visible: Media.available
            width: Math.min(320, implicitWidth)
            text: Media.nowPlaying
            color: pointer.pressed ? Theme.bg0 : Theme.fg0
            elide: Text.ElideMiddle
            font.family: Theme.uiFont
            font.pixelSize: Theme.textSize
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        visible: root.openHere
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.indicatorHeight
        color: Theme.orangeBright
    }

    Rectangle {
        visible: root.occupied
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 4
        height: 4
        radius: 2
        color: root.openHere ? Theme.orangeBright : Theme.fgMuted
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (mouse.button === Qt.RightButton)
                Media.togglePlaying();
            else
                root.toggleScratchpad();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.toggleScratchpad();
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
        show: root.hovered || root.activeFocus
        text: (root.openHere ? "Hide" : "Show") + " music scratchpad · Win+Caps Lock" + (Media.available ? "\n" + Media.nowPlaying + "\nRight: " + (Media.playing ? "pause" : "play") : "")
    }
}
