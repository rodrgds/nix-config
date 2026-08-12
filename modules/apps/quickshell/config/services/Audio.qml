pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property string description: {
        if (!available)
            return "No audio output";
        return sink.description || sink.nickname || sink.name || "Default output";
    }

    function toggleMuted(): void {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    function adjustVolume(delta: real): void {
        if (!available)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
        if (sink.audio.muted && delta > 0)
            sink.audio.muted = false;
    }

    PwObjectTracker {
        objects: [root.sink]
    }
}
