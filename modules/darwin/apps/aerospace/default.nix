{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.aerospace;

  # Helper to convert hex color to 0x format for Aerospace
  toAerospaceColor = hex: "0xff${lib.strings.removePrefix "#" hex}";

  colors = constants.colors;
in
{
  options.darwin.apps.aerospace = {
    enable = lib.mkEnableOption "Enable Aerospace tiling window manager";
  };

  config = lib.mkIf cfg.enable {
    # Install Aerospace via Homebrew cask
    homebrew.casks = [ "aerospace" ];

    # Aerospace configuration via home-manager
    home-manager.users.${username} = {
      home.file = {
        ".aerospace.toml".text = ''
          # AeroSpace configuration
          # Based on i3 configuration from NixOS
          # Gruvbox Dark theme

          # Config version
          config-version = 2

          # Start at login
          start-at-login = true

          # Normalization (similar to i3 behavior)
          enable-normalization-flatten-containers = true
          enable-normalization-opposite-orientation-for-nested-containers = true

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
          outer.top = 3
          outer.right = 3

           # Main binding mode (equivalent to i3 default)
           [mode.main.binding]
           # Workspaces (alt+number, similar to Mod4+number in i3)
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

           # Move windows to workspaces (alt+shift+number)
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

           # Window focus (vim-style, matching i3's j/k/b/o layout)
           # Note: Aerospace uses h/j/k/l, i3 uses j/k/b/o
           # Arrow key focus removed - use alt+h/j/k/l instead to keep alt+arrows free for text editing
           alt-h = 'focus left'
           alt-j = 'focus down'
           alt-k = 'focus up'
           alt-l = 'focus right'

           # Move windows
           alt-shift-h = 'move left'
           alt-shift-j = 'move down'
           alt-shift-k = 'move up'
           alt-shift-l = 'move right'

            # Window management
            # Use AppleScript to send Cmd+Q for proper app quitting on macOS
            alt-q = "close --quit-if-last-window"
            alt-f = 'fullscreen'
            alt-space = 'layout floating tiling'

            # Layouts (matching i3)
            alt-s = 'layout accordion horizontal vertical'
            alt-g = 'layout tiles horizontal vertical'
            # alt-e removed - Aerospace doesn't have 'layout toggle' command
            # alt-a removed - Aerospace doesn't have 'focus parent' command

           # Resize
           alt-minus = 'resize smart -50'
           alt-equal = 'resize smart +50'

            # Application launching (using -n flag to always open new instances)
            alt-enter = 'exec-and-forget open -na Ghostty'
            alt-w = 'exec-and-forget open -na "Microsoft Edge"'
            alt-n = 'exec-and-forget open -a Finder'

            # Screenshots (Flameshot)
             alt-shift-s = 'exec-and-forget /Applications/flameshot.app/Contents/MacOS/flameshot gui'

           # Launcher (Raycast instead of rofi/vicinae)
           alt-d = 'exec-and-forget open -a Raycast'

           # Lock screen (macOS native) - using alt+ctrl+l to avoid conflict with focus right
           alt-ctrl-l = 'exec-and-forget pmset displaysleepnow'

            # Config reload (matching i3 - both alt-shift-c and alt-shift-r work)
            alt-shift-c = 'reload-config'
            alt-shift-r = 'reload-config'

           # Workspace navigation
           alt-tab = 'workspace-back-and-forth'
           alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

           # Service mode (like i3's resize mode)
           alt-shift-semicolon = 'mode service'

           # Service mode bindings
           [mode.service.binding]
           esc = ['reload-config', 'mode main']
           r = ['flatten-workspace-tree', 'mode main']
           f = ['layout floating tiling', 'mode main']
           backspace = ['close-all-windows-but-current', 'mode main']

           # Join windows (similar to i3 split)
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
          if.app-id = 'md.obsidian'
          run = 'move-node-to-workspace 3'

          [[on-window-detected]]
          if.app-id = 'com.beeper'
          run = 'move-node-to-workspace 5'

          [[on-window-detected]]
          if.app-id = 'com.stremio.stremio'
          run = 'move-node-to-workspace 6'

          # Float specific window types
          [[on-window-detected]]
          if.window-title-regex-substring = '^(Picture-in-Picture|PiP)'
          run = 'layout floating'

          [[on-window-detected]]
          if.app-id = 'com.apple.systempreferences'
          run = 'layout floating'

          [[on-window-detected]]
          if.app-id = 'com.apple.finder'
          if.window-title-regex-substring = '(Info|Preferences)'
          run = 'layout floating'
        '';
      };
    };
  };
}
