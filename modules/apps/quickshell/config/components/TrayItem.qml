import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs

Item {
    id: root

    required property var item
    readonly property bool needsAttention: item.status === Status.NeedsAttention
    readonly property string baseAccessibleLabel: item.tooltipTitle || item.title || item.id || "Tray item"
    readonly property string accessibleLabel: baseAccessibleLabel + (needsAttention ? ", needs attention" : "")

    function primaryAction(): void {
        if (item.onlyMenu && item.hasMenu)
            menuAnchor.open();
        else
            item.activate();
    }

    implicitWidth: Theme.controlMinWidth
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.description: (needsAttention ? "Needs attention. " : "") + (item.tooltipDescription || "System tray item")
    Accessible.onPressAction: root.primaryAction()

    Rectangle {
        anchors.fill: parent
        color: pointer.pressed ? Theme.bg2 : pointer.containsMouse ? Theme.bg1 : "transparent"
        border.color: root.activeFocus ? Theme.orangeBright : root.needsAttention ? Theme.redBright : "transparent"
        border.width: 1
        radius: 3
    }

    Image {
        id: trayIcon
        anchors.centerIn: parent
        width: 16
        height: 16
        source: root.item.icon
        sourceSize.width: 16
        sourceSize.height: 16
        cache: false
        fillMode: Image.PreserveAspectFit
    }

    Text {
        anchors.centerIn: parent
        visible: root.item.icon === "" || trayIcon.status === Image.Error
        text: "•"
        color: root.needsAttention ? Theme.redBright : Theme.fgMuted
        font.family: Theme.primaryFont
        font.pixelSize: Theme.iconSize
    }

    Rectangle {
        visible: root.needsAttention
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 6
        height: 2
        color: Theme.redBright
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.item.menu
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.All
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (mouse.button === Qt.RightButton && root.item.hasMenu)
                menuAnchor.open();
            else if (mouse.button === Qt.MiddleButton)
                root.item.secondaryActivate();
            else if (mouse.button === Qt.LeftButton)
                root.primaryAction();
        }
        onWheel: wheel => {
            root.item.scroll(wheel.angleDelta.y, false);
            wheel.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.primaryAction();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) && root.item.hasMenu) {
            menuAnchor.open();
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
        text: root.item.tooltipDescription ? root.accessibleLabel + "\n" + root.item.tooltipDescription : root.accessibleLabel
    }
}
