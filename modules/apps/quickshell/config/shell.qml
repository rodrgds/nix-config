//@ pragma IconTheme Papirus
//@ pragma UseQApplication

/*
THESIS: A zero-distraction instrument rail makes workspace motion and system health readable without becoming another desktop surface.
OWN-WORLD: Opaque Flexoki black, compact mono labels, orange focus, hairline meters, and square edge-to-edge controls.
STORY: Read the active workspace and music scratchpad first, scan machine pressure second, then act on audio, tray items, or power without leaving the rail.
FIRST VIEWPORT: A 28px bar spans each monitor; workspaces 1–9 and live music sit left, flexible quiet space stays central, and status plus controls terminate at the right edge.
FORM: First-ranked compact instrument rail, staged as a per-monitor operational strip; seed key brief-pinned/no-roll.
*/

import Quickshell
import Quickshell.Io
import qs

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    AskpassModal {
        id: askpassModal
    }

    IpcHandler {
        target: "askpass"

        function request(socketPath: string, command: string): bool {
            return askpassModal.request(socketPath, command);
        }
    }
}
