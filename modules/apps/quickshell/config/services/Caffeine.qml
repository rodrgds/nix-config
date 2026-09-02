pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool active: false

    function toggle(): void {
        if (!toggleProcess.running)
            toggleProcess.running = true;
    }

    function refresh(): void {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function adopt(output: string): void {
        root.active = output.trim() === "on";
    }

    Process {
        id: statusProcess
        command: [Runtime.bashPath, Runtime.scriptDir + "/toggle_caffeine.sh", "status"]

        stdout: StdioCollector {
            onStreamFinished: root.adopt(text)
        }
    }

    Process {
        id: toggleProcess
        command: [Runtime.bashPath, Runtime.scriptDir + "/toggle_caffeine.sh"]

        stdout: StdioCollector {
            onStreamFinished: root.adopt(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
