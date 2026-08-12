pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property int activeIndex: 0
    property string activeKeymap: "English (US)"

    readonly property string currentName: activeIndex === 1 ? "Portuguese" : "English"
    readonly property string nextName: activeIndex === 1 ? "English" : "Portuguese"
    readonly property string nextLabel: activeIndex === 1 ? "EN" : "PT"

    function update(output: string): void {
        try {
            const devices = JSON.parse(output);
            const keyboards = devices.keyboards || [];
            if (keyboards.length === 0)
                return;

            let keyboard = keyboards.find(candidate => candidate.main) || keyboards[0];
            activeIndex = keyboard.active_layout_index;
            activeKeymap = keyboard.active_keymap || currentName;
        } catch (error) {
            console.warn("Could not read the active keyboard layout:", error);
        }
    }

    Process {
        id: devicesProcess
        command: [Runtime.hyprctlPath, "devices", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.update(text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!devicesProcess.running)
                devicesProcess.running = true;
        }
    }
}
