{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.polybar;
in
{
  options.apps.polybar = {
    enable = lib.mkEnableOption "Enable polybar";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = _: {
      home.file = {
        ".config/polybar/config.ini".text = ''
          [colors]
          bg = #100F0F
          bg-alt = #1C1B1A
          bg-hover = #282726
          fg = #CECDC3
          fg-alt = #6F6E69
          accent = #BC5215
          highlight = #DA702C
          urgent = #D14D41
          success = #879A39
          warning = #D0A215

          [bar/main]
          monitor = ''${env:MONITOR:}
          width = 100%
          height = 28
          radius = 0
          fixed-center = true
          bottom = false
          background = ''${colors.bg}
          foreground = ''${colors.fg}
          line-size = 0
          border-size = 0
          padding-left = 4
          padding-right = 4
          module-margin-left = 2
          module-margin-right = 2
          font-0 = "${constants.fonts.primary}:style=Regular:size=11;2"
          font-1 = "${constants.fonts.primary}:style=Regular:size=11;2"
          font-2 = "Font Awesome 7 Free:style=Regular:size=11;2"
          font-3 = "Font Awesome 7 Free Solid:style=Solid:size=11;2"
          font-4 = "Font Awesome 7 Brands:style=Regular:size=11;2"
          separator =
          modules-left = i3
          modules-center =
          modules-right = cpu memory disk pulseaudio kb sound res layout tray date power
          cursor-click = pointer
          cursor-scroll = ns-resize
          enable-ipc = true
          wm-restack = generic

          [module/i3]
          type = internal/i3
          pin-workspaces = false
          strip-wsnumbers = false
          show-urgent = true
          index-sort = true
          enable-click = true
          enable-scroll = false
          wrapping-scroll = true
          label-mode-padding = 4
          label-mode-foreground = ''${colors.bg}
          label-mode-background = ''${colors.warning}
          label-focused = %name% 
          label-focused-foreground = ''${colors.bg}
          label-focused-background = ''${colors.accent}
          label-focused-padding = 2
          label-unfocused = %name% 
          label-unfocused-foreground = ''${colors.fg-alt}
          label-unfocused-padding = 2
          label-visible = %name% 
          label-visible-foreground = ''${colors.fg}
          label-visible-underline = ''${colors.fg-alt}
          label-visible-padding = 2
          label-urgent = %name% 
          label-urgent-foreground = ''${colors.bg}
          label-urgent-background = ''${colors.urgent}
          label-urgent-padding = 2

          [module/cpu]
          type = internal/cpu
          interval = 2
          format = <label> <ramp-coreload>
          label = CPU %percentage%%
          label-foreground = ''${colors.fg}
          ramp-coreload-0 = ▁
          ramp-coreload-1 = ▂
          ramp-coreload-2 = ▃
          ramp-coreload-3 = ▄
          ramp-coreload-4 = ▅
          ramp-coreload-5 = ▆
          ramp-coreload-6 = ▇
          ramp-coreload-7 = █
          ramp-coreload-foreground = ''${colors.highlight}
          ramp-coreload-spacing = 1

          [module/memory]
          type = internal/memory
          interval = 5
          format = <label> <bar-used>
          label = RAM %gb_used%
          label-foreground = ''${colors.fg}
          bar-used-width = 20
          bar-used-indicator =
          bar-used-fill = │
          bar-used-empty = │
          bar-used-foreground = ''${colors.accent}
          bar-used-empty-foreground = ''${colors.bg-hover}
          warn-percentage = 90

          [module/disk]
          type = internal/fs
          mount-0 = /
          interval = 30
          format-mounted = <label-mounted>
          label-mounted = DISK %free%
          label-mounted-foreground = ''${colors.fg}

          [module/pulseaudio]
          type = internal/pulseaudio
          use-ui-max = false
          interval = 5
          format-volume = <ramp-volume> <label-volume>
          label-volume = %percentage%%
          label-volume-foreground = ''${colors.fg}
          label-muted = 🔇
          label-muted-foreground = ''${colors.fg-alt}
          ramp-volume-0 = 🔈
          ramp-volume-1 = 🔉
          ramp-volume-2 = 🔊
          click-right = pavucontrol

          [module/date]
          type = internal/date
          interval = 1
          date = %a %d %b
          time = %H:%M
          format = <label>
          label = %time%  %date%
          label-foreground = ''${colors.fg}
          label-font = 1

          [module/layout]
          type = custom/script
          exec = echo " 󰍹 "
          interval = 999999
          format-padding = 1
          click-left = "${constants.scriptDir}/1monitor.sh && sleep 1 && ${constants.homeDir}/.config/polybar/launch.sh"

          [module/kb]
          type = custom/script
          exec = echo "  "
          interval = 999999
          format-padding = 1
          click-left = ${constants.scriptDir}/toggle_keyboard_layout.sh

          [module/sound]
          type = custom/script
          exec = echo "  "
          interval = 999999
          format-padding = 1
          click-left = ${constants.scriptDir}/toggle_sound_device.sh

          [module/res]
          type = custom/script
          exec = echo "  "
          interval = 999999
          format-padding = 1
          click-left = "${constants.scriptDir}/fullres.sh && sleep 1 && ${constants.homeDir}/.config/polybar/launch.sh"

          [module/tray]
          type = internal/tray
          tray-spacing = 4

          [module/power]
          type = custom/menu
          label-open = ⏻
          label-open-foreground = ''${colors.fg}
          label-close = ✕
          label-close-foreground = ''${colors.fg-alt}
          label-separator = |
          menu-0-0 = Lock
          menu-0-0-exec = i3lock
          menu-0-1 = Logout
          menu-0-1-exec = i3-msg exit
          menu-0-2 = Suspend
          menu-0-2-exec = systemctl suspend
          menu-0-3 = Reboot
          menu-0-3-exec = systemctl reboot
          menu-0-4 = Shutdown
          menu-0-4-exec = systemctl poweroff
        '';

        ".config/polybar/launch.sh".text = ''
          #!/usr/bin/env bash
          polybar-msg cmd quit 2>/dev/null || true
          while pgrep -x polybar >/dev/null; do sleep 0.3; done
          polybar --reload main &
        '';

        ".config/polybar/launch.sh".executable = true;
      };
    };

    environment.systemPackages = [ pkgs.polybar ];
  };
}
