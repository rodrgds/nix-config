import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    aboveWindows: true
    focusable: true
    color: Theme.bg0
    surfaceFormat.opaque: true

    WlrLayershell.namespace: "rgo-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.outerGutter
        anchors.rightMargin: Theme.outerGutter
        spacing: Theme.itemGap

        WorkspaceStrip {
            barScreen: root.screen
            Layout.alignment: Qt.AlignVCenter
        }

        MusicScratchpad {
            barScreen: root.screen
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        MetricWidget {
            title: "CPU"
            value: Math.round(SystemStats.cpuPercent) + "%"
            progress: SystemStats.cpuPercent / 100
            accent: Theme.orangeBright
            tooltipText: "CPU " + SystemStats.cpuPercent.toFixed(1) + "%\n\nTop processes\n" + SystemStats.topCpuProcesses
            Layout.alignment: Qt.AlignVCenter
        }

        MetricWidget {
            title: "RAM"
            value: SystemStats.memoryUsedGiB.toFixed(1) + "G"
            progress: SystemStats.memoryPercent / 100
            accent: SystemStats.memoryPercent >= 90 ? Theme.redBright : Theme.orange
            tooltipText: "Memory " + SystemStats.memoryUsedGiB.toFixed(2) + " GiB (" + Math.round(SystemStats.memoryPercent) + "%)\n\nTop processes\n" + SystemStats.topMemoryProcesses
            Layout.alignment: Qt.AlignVCenter
        }

        MetricWidget {
            title: "DISK"
            value: SystemStats.diskFreeGiB.toFixed(0) + "G"
            progress: SystemStats.diskPercent / 100
            accent: SystemStats.diskPercent >= 90 ? Theme.redBright : Theme.yellowBright
            tooltipText: "Root filesystem " + SystemStats.diskFreeGiB.toFixed(1) + " GiB free (" + Math.round(SystemStats.diskPercent) + "% used)"
            Layout.alignment: Qt.AlignVCenter
        }

        AudioWidget {
            Layout.alignment: Qt.AlignVCenter
        }

        ToolButton {
            label: Keyboard.nextLabel
            tooltipText: "Switch to " + Keyboard.nextName + "\nCurrent: " + Keyboard.currentName
            onTriggered: button => {
                if (button === Qt.LeftButton)
                    Runtime.runScript("toggle_keyboard_layout.sh");
            }
            Layout.alignment: Qt.AlignVCenter
        }

        ToolButton {
            label: ""
            fontFamily: Theme.monoFont
            active: Caffeine.active
            tooltipText: Caffeine.active ? "Caffeine on\n\nThe machine stays awake and never locks.\nClick to allow sleep again" : "Caffeine off\n\nClick to keep the machine awake"
            onTriggered: button => {
                if (button === Qt.LeftButton)
                    Caffeine.toggle();
            }
            Layout.alignment: Qt.AlignVCenter
        }

        TrayWidget {
            Layout.alignment: Qt.AlignVCenter
        }

        ClockWidget {
            Layout.alignment: Qt.AlignVCenter
        }

        ToolButton {
            label: "⏻"
            tooltipText: "Open power menu"
            danger: true
            onTriggered: button => {
                if (button === Qt.LeftButton)
                    Runtime.openPowerMenu();
            }
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
