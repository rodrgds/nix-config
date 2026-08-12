pragma Singleton

import Quickshell

Singleton {
    readonly property string compact: Qt.formatDateTime(clock.date, "HH:mm  ddd dd MMM")
    readonly property string full: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy — HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
