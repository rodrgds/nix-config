{
  lib,
  config,
  pkgs,
  username,
  constants,
  system,
  ...
}:
let
  cfg = config.apps.i3;
  inherit (constants) isLinux;
in
{
  options.apps.i3 = {
    enable = lib.mkEnableOption "Enable i3";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        services.xserver.windowManager.i3 = {
          enable = true;
          extraPackages = with pkgs; [
            autotiling
            redshift
            xcompmgr
            i3lock
            (bumblebee-status.override {
              plugins = p: [
                p.memory
                p.date
                p.time
                p.cpu
                p.layout
                p.uptime
                p.shortcut
              ];
            })
            python3Packages.psutil
            gnome-system-monitor
          ];
        };
      })

      {
        home-manager.users.${username} = _: {
          xsession.windowManager.i3 = {
            enable = true;
            config = {
              modifier = "Mod4";
              terminal = "ghostty";
              fonts = {
                names = [ constants.fonts.primary ];
                size = constants.fonts.sizes.normal;
              };
              #gaps = {
              #  inner = 6;
              #  outer = 3;
              #};
              startup = [
                {
                  command = "dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP=i3";
                  always = false;
                  notification = false;
                }
                {
                  command = "systemctl --user set-environment DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY XDG_CURRENT_DESKTOP=i3";
                  always = false;
                  notification = false;
                }
                {
                  command = "xcompmgr";
                  always = false;
                  notification = false;
                }
                {
                  command = "autotiling";
                  always = true;
                  notification = false;
                }
                {
                  command = "dex --autostart --environment i3";
                  always = false;
                }
                {
                  command = "bash /home/${username}/.config/home/modules/scripts/show_random_wall.sh";
                  always = true;
                }
                {
                  command = "xinput set-prop \"Logitech USB Receiver\" \"libinput Middle Emulation Enabled\" 0";
                  always = true;
                }
                {
                  command = "xset s 480 dpms 600 600 600";
                  always = false;
                }
                {
                  command = "flameshot";
                  always = false;
                }
                {
                  command = "handy --start-hidden";
                  always = true;
                  notification = false;
                }
                {
                  command = "${constants.homeDir}/.config/polybar/launch.sh";
                  always = true;
                  notification = false;
                }
              ];
              keybindings = import ./_helpers/keybindings.nix { inherit pkgs constants; };
              workspaceOutputAssign = import ./_helpers/workspaces.nix { };
              assigns = import ./_helpers/assigns.nix { };
              window.commands = import ./_helpers/window-rules.nix { };
              colors = import ./_helpers/colors.nix { };
              bars = import ./_helpers/bar.nix { inherit pkgs constants; };
            };
          };

          xsession.enable = true;

          xresources.properties = {
            "Xft.dpi" = 96;
            "Xft.autohint" = 0;
            "Xft.lcdfilter" = "lcddefault";
            "Xft.hintstyle" = "hintfull";
            "Xft.hinting" = 1;
            "Xft.antialias" = 1;
            "Xft.rgba" = "rgb";
          };

          home.sessionVariables = {
            GDK_SCALE = "1";
            GDK_DPI_SCALE = "1";
            QT_AUTO_SCREEN_SCALE_FACTOR = "1";
          };
        };
      }
    ]
  );
}
