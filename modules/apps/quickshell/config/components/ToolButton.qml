import QtQuick
import qs

Rectangle {
    id: root

    property string label: ""
    property string tooltipText: ""
    property string fontFamily: Theme.uiFont
    property bool danger: false
    property bool active: false
    readonly property bool hovered: pointer.containsMouse

    signal triggered(int button)
    signal scrolled(real delta)

    implicitWidth: Math.max(Theme.controlMinWidth, buttonLabel.implicitWidth + 12)
    implicitHeight: Theme.controlHeight
    color: {
        if (active)
            return pointer.pressed ? Theme.orange : Theme.orangeBright;
        if (pointer.pressed)
            return danger ? Theme.bg2 : Theme.orangeBright;
        if (hovered)
            return danger ? Theme.bg1 : Theme.bg2;
        return "transparent";
    }
    border.color: danger && hovered ? Theme.redBright : activeFocus ? Theme.orangeBright : "transparent"
    border.width: 1
    radius: Theme.cornerRadius
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || label
    Accessible.description: tooltipText
    Accessible.onPressAction: root.triggered(Qt.LeftButton)

    Text {
        id: buttonLabel
        anchors.centerIn: parent
        text: root.label
        color: root.active || (pointer.pressed && !root.danger) ? Theme.bg0 : Theme.fg0
        font.family: root.fontFamily
        font.pixelSize: Theme.textSize
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggered(mouse.button);
        }
        onWheel: wheel => {
            root.scrolled(wheel.angleDelta.y);
            wheel.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.triggered(Qt.LeftButton);
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
        text: root.tooltipText
    }
}
