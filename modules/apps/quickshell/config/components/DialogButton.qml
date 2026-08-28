import QtQuick
import qs

Rectangle {
    id: root

    required property string label
    property bool primary: false

    signal triggered

    implicitWidth: 112
    implicitHeight: 38
    color: {
        if (!enabled)
            return Theme.bg2;
        if (primary)
            return pointer.pressed ? Theme.orange : Theme.orangeBright;
        return pointer.pressed ? Theme.bg0 : pointer.containsMouse ? Theme.bg2 : Theme.bg1;
    }
    border.color: activeFocus ? Theme.orangeBright : primary ? Theme.orangeBright : Theme.bg2
    border.width: 1
    radius: Theme.cornerRadius
    opacity: enabled ? 1 : 0.55
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (enabled) root.triggered()

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.primary && root.enabled ? Theme.bg0 : Theme.fg0
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.weight: root.primary ? Font.DemiBold : Font.Medium
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!root.enabled)
                return;
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggered();
        }
    }

    Keys.onPressed: event => {
        if (root.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.triggered();
            event.accepted = true;
        }
    }
}
