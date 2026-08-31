/*
THESIS: Administrator approval interrupts clearly without looking foreign to the desktop.
OWN-WORLD: Flexoki warm blacks, restrained orange focus, compact Geist prose, and near-square controls.
STORY: Read the privileged command, enter the password, then authorize or cancel without leaving the current workspace.
FIRST VIEWPORT: A dimmed focused monitor holds one compact 440px panel with the exact command, password input, and two explicit actions.
FORM: A protected operational modal extending the established Quickshell instrument rail.
*/

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    property string responseSocketPath: ""
    property string sudoCommand: ""
    property string pendingResponse: ""

    function focusedScreen(): var {
        for (let index = 0; index < Quickshell.screens.length; index++) {
            const candidate = Quickshell.screens[index];
            if (Hyprland.monitorFor(candidate) === Hyprland.focusedMonitor)
                return candidate;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function validSocketPath(socketPath: string): bool {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        const prefix = runtimeDir + "/rgo-sudo-askpass/request.";
        return runtimeDir.length > 0
            && socketPath.startsWith(prefix)
            && socketPath.endsWith("/reply.sock")
            && !socketPath.includes("..");
    }

    function request(socketPath: string, command: string): bool {
        if (visible || !validSocketPath(socketPath))
            return false;

        const targetScreen = focusedScreen();
        if (targetScreen === null)
            return false;

        screen = targetScreen;
        responseSocketPath = socketPath;
        sudoCommand = command;
        passwordInput.text = "";
        visible = true;
        passwordInput.forceActiveFocus(Qt.ActiveWindowFocusReason);
        return true;
    }

    function respond(accepted: bool): void {
        if (!visible || pendingResponse.length > 0)
            return;
        pendingResponse = accepted ? "A" + passwordInput.text + "\n" : "C\n";
        responseSocket.path = responseSocketPath;
        responseSocket.connected = true;
    }

    function closeRequest(): void {
        visible = false;
        responseSocketPath = "";
        sudoCommand = "";
        passwordInput.text = "";
        pendingResponse = "";
    }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    visible: false
    exclusiveZone: 0
    focusable: true
    color: "transparent"

    WlrLayershell.namespace: "rgo-askpass"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Socket {
        id: responseSocket

        onConnectedChanged: {
            if (!connected || root.pendingResponse.length === 0)
                return;
            write(root.pendingResponse);
            flush();
            connected = false;
            root.closeRequest();
        }
        onError: root.closeRequest()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg0
        opacity: 0.82

        MouseArea {
            anchors.fill: parent
            onClicked: root.respond(false)
        }
    }

    Rectangle {
        id: dialog

        anchors.centerIn: parent
        width: Math.min(440, root.width - 32)
        implicitHeight: content.implicitHeight + 48
        height: implicitHeight
        color: Theme.bg1
        border.color: Theme.bg2
        border.width: 1
        radius: 4

        Accessible.role: Accessible.Dialog
        Accessible.name: "Administrator access"
        Accessible.description: "Enter your password to authorize the requested sudo command."

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: Theme.orangeBright
        }

        ColumnLayout {
            id: content

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 24
            }
            spacing: 0

            Text {
                text: "Run as administrator"
                color: Theme.fg0
                font.family: Theme.uiFont
                font.pixelSize: 20
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                Layout.fillWidth: true
            }

            Rectangle {
                color: Theme.bg0
                radius: Theme.cornerRadius
                implicitHeight: commandText.implicitHeight + 20
                Layout.fillWidth: true
                Layout.topMargin: 16

                Text {
                    id: commandText
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    text: root.sudoCommand.length > 0 ? root.sudoCommand : "sudo"
                    color: Theme.fg0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                    elide: Text.ElideMiddle
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                color: Theme.bg2
                border.color: passwordInput.activeFocus ? Theme.orangeBright : Theme.bg2
                border.width: 1
                radius: Theme.cornerRadius
                implicitHeight: 42
                Layout.fillWidth: true
                Layout.topMargin: 14

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    visible: passwordInput.text.length === 0
                    text: "Password"
                    color: Theme.fgMuted
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: passwordInput
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    color: Theme.fg0
                    selectionColor: Theme.orange
                    selectedTextColor: Theme.bg0
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    activeFocusOnTab: true
                    Accessible.name: "Password"
                    Accessible.passwordEdit: true
                    onAccepted: {
                        if (text.length > 0)
                            root.respond(true);
                    }
                }
            }

            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 22

                DialogButton {
                    label: "Cancel"
                    onTriggered: root.respond(false)
                }

                DialogButton {
                    label: "Authorize"
                    primary: true
                    enabled: passwordInput.text.length > 0
                    onTriggered: root.respond(true)
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.respond(false)
    }
}
