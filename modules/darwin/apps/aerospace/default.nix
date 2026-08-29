{
  lib,
  config,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.aerospace;
  homeDir = "/Users/${username}";
  helperSource = "${inputs.omacosy}/helper/main.swift";
  helperSourceRevision = inputs.omacosy.rev or "9e60b396b5e48a862bcb46bca5f2b13a63a822aa";
  helperBuildId = builtins.hashString "sha256" "${helperSourceRevision}:rgo-aerospace-helper-v1";
  helperBinary = "${homeDir}/.local/libexec/rgo-aerospace-helper";

  workspaceChangeCommands = lib.concatStringsSep "; " (
    lib.optional config.darwin.apps.lightweight-borders.enable ": > /tmp/rgo-aerospace-ws-switch"
    ++ lib.optional config.darwin.apps.sketchybar.enable "${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
  );
in
{
  options.darwin.apps.aerospace = {
    enable = lib.mkEnableOption "Enable Aerospace";
  };

  config = lib.mkIf cfg.enable {
    # Install Aerospace via Homebrew cask
    homebrew.casks = [ "aerospace" ];

    # Aerospace configuration via home-manager
    home-manager.users.${username} =
      { lib, ... }:
      {
        home.file = {
          ".aerospace.toml".text = ''
            # AeroSpace configuration
            # Based on i3 configuration from NixOS
            # Flexoki Dark theme

            # Config version
            config-version = 2

            # Start at login
            start-at-login = true
            # Vicinae is owned by launchd; starting it here as well creates two
            # servers which race over the same control socket.
            after-startup-command = []

            # Keep the border and bar in sync with AeroSpace workspace state.
            exec-on-workspace-change = ['/bin/bash', '-c', '${workspaceChangeCommands}']

            # Set the next split from the focused window's shape. This gives
            # AeroSpace the same stable spiral rule as Hyprland's dwindle layout.
            on-focus-changed = ['exec-and-forget ${helperBinary} split-hint']

            # Normalization (similar to i3 behavior)
            enable-normalization-flatten-containers = false
            enable-normalization-opposite-orientation-for-nested-containers = false

            # Accordion padding (gap between windows in accordion layout)
            accordion-padding = 30

            # Default layout
            default-root-container-layout = 'tiles'
            default-root-container-orientation = 'auto'

             # Mouse follows focus when changing monitors
             on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

            # Automatically unhide macOS hidden apps
            automatically-unhide-macos-hidden-apps = false

            # Persistent workspaces (keep workspaces alive even when empty)
            persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

            # Gaps configuration (matching i3 gaps)
            [gaps]
            inner.horizontal = 6
            inner.vertical = 6
            outer.left = 3
            outer.bottom = 3
            # macOS already reserves the top region for the menu bar or SketchyBar.
            outer.top = 0
            outer.right = 3

             # Main binding mode. Super is Caps Lock held through Karabiner.
             [mode.main.binding]
             # Workspaces and moving windows.
             cmd-ctrl-alt-1 = 'workspace 1'
             cmd-ctrl-alt-2 = 'workspace 2'
             cmd-ctrl-alt-3 = 'workspace 3'
             cmd-ctrl-alt-4 = 'workspace 4'
             cmd-ctrl-alt-5 = 'workspace 5'
             cmd-ctrl-alt-6 = 'workspace 6'
             cmd-ctrl-alt-7 = 'workspace 7'
             cmd-ctrl-alt-8 = 'workspace 8'
             cmd-ctrl-alt-9 = 'workspace 9'
             cmd-ctrl-alt-0 = 'workspace 10'

             alt-1 = 'workspace 1'
             alt-2 = 'workspace 2'
             alt-3 = 'workspace 3'
             alt-4 = 'workspace 4'
             alt-5 = 'workspace 5'
             alt-6 = 'workspace 6'
             alt-7 = 'workspace 7'
             alt-8 = 'workspace 8'
             alt-9 = 'workspace 9'
             alt-0 = 'workspace 10'

             cmd-ctrl-alt-shift-1 = 'move-node-to-workspace 1'
             cmd-ctrl-alt-shift-2 = 'move-node-to-workspace 2'
             cmd-ctrl-alt-shift-3 = 'move-node-to-workspace 3'
             cmd-ctrl-alt-shift-4 = 'move-node-to-workspace 4'
             cmd-ctrl-alt-shift-5 = 'move-node-to-workspace 5'
             cmd-ctrl-alt-shift-6 = 'move-node-to-workspace 6'
             cmd-ctrl-alt-shift-7 = 'move-node-to-workspace 7'
             cmd-ctrl-alt-shift-8 = 'move-node-to-workspace 8'
             cmd-ctrl-alt-shift-9 = 'move-node-to-workspace 9'
             cmd-ctrl-alt-shift-0 = 'move-node-to-workspace 10'

             alt-shift-1 = 'move-node-to-workspace 1'
             alt-shift-2 = 'move-node-to-workspace 2'
             alt-shift-3 = 'move-node-to-workspace 3'
             alt-shift-4 = 'move-node-to-workspace 4'
             alt-shift-5 = 'move-node-to-workspace 5'
             alt-shift-6 = 'move-node-to-workspace 6'
             alt-shift-7 = 'move-node-to-workspace 7'
             alt-shift-8 = 'move-node-to-workspace 8'
             alt-shift-9 = 'move-node-to-workspace 9'
             alt-shift-0 = 'move-node-to-workspace 10'

             # Focus and move without taking Option+Arrow away from editors.
             cmd-ctrl-alt-left = 'focus left'
             cmd-ctrl-alt-down = 'focus down'
             cmd-ctrl-alt-up = 'focus up'
             cmd-ctrl-alt-right = 'focus right'
             cmd-ctrl-alt-shift-left = 'move left'
             cmd-ctrl-alt-shift-down = 'move down'
             cmd-ctrl-alt-shift-up = 'move up'
             cmd-ctrl-alt-shift-right = 'move right'

             alt-h = 'focus left'
             alt-j = 'focus down'
             alt-k = 'focus up'
             alt-l = 'focus right'
             alt-shift-h = 'move left'
             alt-shift-j = 'move down'
             alt-shift-k = 'move up'
             alt-shift-l = 'move right'

             # Window and layout controls.
             cmd-ctrl-alt-w = 'close --quit-if-last-window'
             cmd-ctrl-alt-f = 'fullscreen --no-outer-gaps'
             cmd-ctrl-alt-t = 'layout floating tiling'
             cmd-ctrl-alt-j = 'layout tiles horizontal vertical'
             cmd-ctrl-alt-s = 'layout accordion horizontal vertical'
             cmd-ctrl-alt-g = 'layout tiles horizontal vertical'
             cmd-ctrl-alt-minus = 'resize smart -50'
             cmd-ctrl-alt-equal = 'resize smart +50'

             alt-q = 'close --quit-if-last-window'
             alt-f = 'fullscreen'
             alt-space = 'layout floating tiling'
             alt-s = 'layout accordion horizontal vertical'
             alt-g = 'layout tiles horizontal vertical'
             alt-minus = 'resize smart -50'
             alt-equal = 'resize smart +50'

             # Apps and launcher.
             cmd-ctrl-alt-enter = 'exec-and-forget open -na Ghostty'
             cmd-ctrl-alt-shift-enter = 'exec-and-forget open -na "Brave Browser"'
             cmd-ctrl-alt-shift-f = 'exec-and-forget open -a Finder'
             cmd-ctrl-alt-space = 'exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher toggle'
             cmd-ctrl-alt-d = 'exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher toggle'
             cmd-ctrl-alt-period = "exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher 'vicinae://launch/core/search-emojis'"

             alt-enter = 'exec-and-forget open -na Ghostty'
             alt-w = 'exec-and-forget open -na "Brave Browser"'
             alt-n = 'exec-and-forget open -a Finder'
             alt-d = 'exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher toggle'
             alt-period = "exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher 'vicinae://launch/core/search-emojis'"

             # Screenshot annotation and screen color picker.
             cmd-ctrl-alt-shift-s = 'exec-and-forget /usr/bin/open "shottr://grab/area?then=edit"'
             alt-shift-s = 'exec-and-forget /usr/bin/open "shottr://grab/area?then=edit"'
             cmd-ctrl-alt-shift-c = 'exec-and-forget /usr/bin/open "pika://pick/foreground/hex"'
             alt-shift-c = 'exec-and-forget /usr/bin/open "pika://pick/foreground/hex"'

               # Match the desktop input-source toggle. Requires the keyboard-layout module.
               ${
                 if config.darwin.apps.keyboard-layout.enable then
                   ''
                     cmd-ctrl-alt-m = 'exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/toggle-keyboard-layout'
                     alt-m = 'exec-and-forget ${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin/toggle-keyboard-layout'
                   ''
                 else
                   "# Super+M and Option+M: keyboard-layout module is disabled"
               }

             # Lock and reload.
             cmd-ctrl-alt-shift-l = 'exec-and-forget ${helperBinary} lock'
             cmd-ctrl-alt-shift-r = 'reload-config'
             alt-ctrl-l = 'exec-and-forget pmset displaysleepnow'
             alt-shift-r = 'reload-config'

             # Workspace navigation.
             cmd-ctrl-alt-tab = 'workspace --wrap-around next'
             cmd-ctrl-alt-shift-tab = 'workspace --wrap-around prev'
             cmd-ctrl-alt-b = 'workspace-back-and-forth'
             alt-tab = 'workspace-back-and-forth'
             alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

             # Service mode.
             cmd-ctrl-alt-shift-semicolon = 'mode service'
             alt-shift-semicolon = 'mode service'

             # Service mode bindings
             [mode.service.binding]
             esc = ['reload-config', 'mode main']
             r = ['flatten-workspace-tree', 'mode main']
             f = ['layout floating tiling', 'mode main']
             backspace = ['close-all-windows-but-current', 'mode main']

             # Join windows.
             h = ['join-with left', 'mode main']
             j = ['join-with down', 'mode main']
             k = ['join-with up', 'mode main']
             l = ['join-with right', 'mode main']
             alt-shift-h = ['join-with left', 'mode main']
             alt-shift-j = ['join-with down', 'mode main']
             alt-shift-k = ['join-with up', 'mode main']
             alt-shift-l = ['join-with right', 'mode main']

            # Window detection callbacks - auto-assign apps to workspaces
            [[on-window-detected]]
            if.app-id = 'com.mitchellh.ghostty'
            run = 'move-node-to-workspace 1'

            [[on-window-detected]]
            if.app-id = 'com.microsoft.edgemac'
            run = 'move-node-to-workspace 2'

            [[on-window-detected]]
            if.app-id = 'com.google.Chrome'
            run = 'move-node-to-workspace 2'

            [[on-window-detected]]
            if.app-id = 'md.obsidian'
            run = 'move-node-to-workspace 4'

            [[on-window-detected]]
            if.app-id = 'com.beeper'
            run = 'move-node-to-workspace 5'

            # Workspace 10 is the macOS equivalent of the desktop music scratchpad.
            [[on-window-detected]]
            if.app-id = 'com.spotify.client'
            run = 'move-node-to-workspace 10'

            [[on-window-detected]]
            if.app-id = 'com.apple.Music'
            run = 'move-node-to-workspace 10'

            [[on-window-detected]]
            if.app-id = 'com.brave.Browser'
            run = 'move-node-to-workspace 2'

            # Float specific window types
            [[on-window-detected]]
            if.window-title-regex-substring = '^(Picture-in-Picture|PiP)'
            run = 'layout floating'

            [[on-window-detected]]
            if.app-id = 'com.apple.systempreferences'
            run = 'layout floating'

            [[on-window-detected]]
            if.app-id = 'com.apple.finder'
            run = 'move-node-to-workspace 3'

            # Float specific Finder windows (Info, Preferences)
            [[on-window-detected]]
            if.app-id = 'com.apple.finder'
            if.window-title-regex-substring = '(Info|Preferences)'
            run = 'layout floating'
          '';
        };

        home.activation.compileAerospaceHelper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          set -eu

          /bin/mkdir -p ${homeDir}/.local/libexec
          stamp=${homeDir}/.local/libexec/.rgo-aerospace-helper-source

          if [ ! -x ${helperBinary} ] || [ ! -f "$stamp" ] || [ "$(/bin/cat "$stamp")" != ${lib.escapeShellArg helperBuildId} ]; then
            build_dir="$(/usr/bin/mktemp -d /tmp/rgo-aerospace-helper.XXXXXX)"
            trap '/bin/rm -rf "$build_dir"' EXIT

            /usr/bin/sed \
              -e 's|/tmp/omacosy-split-state-|/tmp/rgo-aerospace-split-state-|g' \
              -e 's|/tmp/omacosy-split-hint.log|/tmp/rgo-aerospace-split-hint.log|g' \
              ${helperSource} > "$build_dir/helper.swift"

            /usr/bin/xcrun swiftc -O \
              -F /System/Library/PrivateFrameworks \
              -framework DisplayServices \
              -o "$build_dir/rgo-aerospace-helper" \
              "$build_dir/helper.swift"
            /usr/bin/codesign --force --sign - --identifier dev.rgo.aerospace-helper "$build_dir/rgo-aerospace-helper"
            /bin/mv "$build_dir/rgo-aerospace-helper" ${helperBinary}
            printf '%s\n' ${lib.escapeShellArg helperBuildId} > "$stamp"
          fi
        '';
      };
  };
}
