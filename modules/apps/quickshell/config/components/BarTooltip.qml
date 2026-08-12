import QtQuick
import Quickshell
import qs

PopupWindow {
    id: root

    required property Item anchorItem
    required property string text
    property bool show: false

    color: "transparent"
    implicitWidth: tooltipText.implicitWidth + 12
    implicitHeight: tooltipText.implicitHeight + 10
    grabFocus: false

    anchor {
        window: root.anchorItem.QsWindow.window
        adjustment: PopupAdjustment.All
        gravity: Edges.Bottom | Edges.Right

        onAnchoring: {
            const position = root.anchorItem.QsWindow.contentItem.mapFromItem(
                root.anchorItem,
                root.anchorItem.width / 2 - root.width / 2,
                root.anchorItem.height + 4
            );
            anchor.rect.x = position.x;
            anchor.rect.y = position.y;
        }
    }

    onShowChanged: {
        if (show)
            delayTimer.restart();
        else {
            delayTimer.stop();
            visible = false;
        }
    }

    Timer {
        id: delayTimer
        interval: 450
        onTriggered: root.visible = root.show
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg1
        border.color: Theme.bg2
        border.width: 1
        radius: 4
    }

    Text {
        id: tooltipText
        anchors.centerIn: parent
        text: root.text
        color: Theme.fg0
        font.family: Theme.uiFont
        font.pixelSize: 11
        renderType: Text.NativeRendering
    }
}
