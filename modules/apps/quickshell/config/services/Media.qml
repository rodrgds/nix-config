pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var player: {
        const players = Mpris.players.values;
        let fallback = null;

        for (const candidate of players) {
            if (candidate.trackTitle === "")
                continue;
            if (candidate.isPlaying)
                return candidate;
            if (fallback === null)
                fallback = candidate;
        }

        return fallback;
    }
    readonly property bool available: player !== null
    readonly property bool playing: available && player.isPlaying
    readonly property string title: available ? player.trackTitle : ""
    readonly property string artist: available ? player.trackArtist : ""
    readonly property string nowPlaying: {
        if (!available)
            return "Music";
        if (artist === "")
            return title;
        return artist + " — " + title;
    }

    function togglePlaying(): void {
        if (available && player.canTogglePlaying)
            player.togglePlaying();
    }
}
