import QtQuick
import qs
import qs.services

ToolButton {
    id: root

    readonly property int percent: Math.round(Audio.volume * 100)
    readonly property string icon: {
        if (!Audio.available || Audio.muted)
            return "\uf6a9";
        if (Audio.volume < 0.34)
            return "\uf026";
        if (Audio.volume < 0.67)
            return "\uf027";
        return "\uf028";
    }

    label: Audio.available ? icon + " " + percent + "%" : "\uf6a9"
    tooltipText: Audio.description + "\nLeft: switch output · Right: mixer · Wheel: volume"

    onTriggered: button => {
        if (button === Qt.RightButton)
            Runtime.openPavucontrol();
        else if (button === Qt.LeftButton)
            Runtime.runScript("toggle_sound_device.sh");
    }
    onScrolled: delta => Audio.adjustVolume(delta > 0 ? 0.05 : -0.05)
}
