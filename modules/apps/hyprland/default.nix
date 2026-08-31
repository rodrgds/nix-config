{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.hyprland;
  inherit (constants) isLinux;

  hyprlandPackage = config.programs.hyprland.package;
  hyprlandSessionPath =
    lib.makeBinPath [ hyprlandPackage ]
    + ":/run/wrappers/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin";
  hyprlandUWSMLauncher = pkgs.writeShellApplication {
    name = "Hyprland";
    text = ''
      export PATH=${hyprlandSessionPath}:$PATH
      exec ${lib.getExe' hyprlandPackage "start-hyprland"} \
        --path ${lib.getExe hyprlandPackage} \
        -- "$@"
    '';
  };

  color = name: lib.removePrefix "#" constants.colors.${name};
  hyprlandLua =
    lib.replaceStrings
      [
        "@scriptDir@"
        "@uiFont@"
        "@bg0@"
        "@bg2@"
        "@fg0@"
        "@fg1@"
        "@orange@"
        "@orangeBright@"
        "@red@"
        "@hyprpicker@"
      ]
      [
        constants.scriptDir
        constants.fonts.ui
        (color "bg0")
        (color "bg2")
        (color "fg0")
        (color "fg1")
        (color "orange")
        (color "orangeBright")
        (color "red")
        (lib.getExe pkgs.hyprpicker)
      ]
      (builtins.readFile ./hyprland.lua);

  hyprlandCondition = "${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition 'Hyprland' ''";
  sddmTheme = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    themeConfig = {
      Font = constants.fonts.ui;
      FontSize = 12;
      RoundCorners = 8;
      HeaderText = "rgo-desktop";
      HourFormat = "HH:mm";
      DateFormat = "dddd, d MMMM";
      DimBackground = 0.38;
      DimBackgroundColor = constants.colors.bg0;
      FormPosition = "center";
      HaveFormBackground = false;
      PartialBlur = false;
      FullBlur = false;
      ForceLastUser = true;
      PasswordFocus = true;
      HideVirtualKeyboard = true;
      HeaderTextColor = constants.colors.fg0;
      DateTextColor = constants.colors.fg1;
      TimeTextColor = constants.colors.fg0;
      FormBackgroundColor = constants.colors.bg1;
      BackgroundColor = constants.colors.bg0;
      LoginFieldBackgroundColor = constants.colors.bg2;
      PasswordFieldBackgroundColor = constants.colors.bg2;
      LoginFieldTextColor = constants.colors.fg0;
      PasswordFieldTextColor = constants.colors.fg0;
      UserIconColor = constants.colors.orangeBright;
      PasswordIconColor = constants.colors.orangeBright;
      PlaceholderTextColor = constants.colors.fg1;
      WarningColor = constants.colors.redBright;
      LoginButtonTextColor = constants.colors.bg0;
      LoginButtonBackgroundColor = constants.colors.orangeBright;
      SystemButtonsIconsColor = constants.colors.fg0;
      SessionButtonTextColor = constants.colors.fg0;
      DropdownTextColor = constants.colors.fg0;
      DropdownSelectedBackgroundColor = constants.colors.orange;
      DropdownBackgroundColor = constants.colors.bg2;
      HighlightTextColor = constants.colors.bg0;
      HighlightBackgroundColor = constants.colors.orangeBright;
      HighlightBorderColor = constants.colors.orangeBright;
      HoverUserIconColor = constants.colors.fg0;
      HoverPasswordIconColor = constants.colors.fg0;
      HoverSystemButtonsIconsColor = constants.colors.orangeBright;
      HoverSessionButtonTextColor = constants.colors.orangeBright;
    };
  };
in
{
  options.apps.hyprland = {
    enable = lib.mkEnableOption "Enable Hyprland and its Wayland session services";
  };
}
// lib.optionalAttrs isLinux {

  # Omit Linux-only option paths entirely on Darwin. A false mkIf still leaves
  # those paths visible to the module checker, where their options do not exist.
  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    programs.uwsm.waylandCompositors.hyprland-rgo = {
      prettyName = "Hyprland";
      comment = "Hyprland compositor managed by UWSM";
      binPath = "${hyprlandUWSMLauncher}/bin/Hyprland";
    };

    # Keep live rebuilds from restarting UWSM lifecycle services. Stopping any
    # of these triggers a full graphical-session shutdown by design. UWSM also
    # prepares the graphical-session environment itself, so its units must not
    # replace the manager's PATH with NixOS's minimal service default.
    systemd.user.services = {
      "wayland-session-bindpid@" = {
        enableDefaultPath = false;
        restartIfChanged = false;
      };
      "wayland-wm-env@" = {
        enableDefaultPath = false;
        restartIfChanged = false;
      };
      "wayland-wm@" = {
        enableDefaultPath = false;
        restartIfChanged = false;
      };
    };

    # Keep the greeter on X11 for predictable NVIDIA startup; the desktop
    # session itself is UWSM-managed Hyprland on Wayland.
    services.displayManager = {
      defaultSession = "hyprland-rgo-uwsm";
      sddm = {
        enable = true;
        wayland.enable = false;
        theme = "sddm-astronaut-theme";
        extraPackages = [ sddmTheme ];
      };
    };

    security.pam.services.hyprlock = { };

    environment.systemPackages = with pkgs; [
      awww
      grim
      hyprpicker
      hyprsunset
      sddmTheme
      slurp
      wl-clipboard
    ];

    home-manager.users.${username} =
      { config, ... }:
      {
        # UWSM sources the Home Manager session environment before starting
        # the compositor and all graphical-session services.
        xdg.configFile."uwsm/env".source =
          "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

        # Cap Discord/OBS capture at a useful ceiling, remember approved
        # sources, and include the pointer in clients that do not request a
        # cursor mode. SHM avoids Electron's unreliable NVIDIA DMA-BUF import;
        # the 5700X has ample headroom for two 1080p outputs at this ceiling.
        xdg.configFile."hypr/xdph.conf".text = ''
          screencopy {
            max_fps = 60
            allow_token_by_default = true
            force_shm = true
            cursor_mode = 2
          }
        '';

        # Select native Wayland where available without forcing applications
        # whose own compatibility still requires XWayland. Defining these in
        # Home Manager makes the UWSM environment file above authoritative.
        home.sessionVariables = {
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          LIBVA_DRIVER_NAME = "nvidia";
          NVD_BACKEND = "direct";
          NIXOS_OZONE_WL = "1";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        };

        wayland.windowManager.hyprland = {
          enable = true;
          # Use the package installed by the required NixOS module so the
          # compositor, session entry, and portal cannot drift apart.
          package = null;
          portalPackage = null;
          configType = "lua";
          systemd.enable = false;
          xwayland.enable = true;
          extraConfig = hyprlandLua;
        };

        programs.hyprlock = {
          enable = true;
          settings = {
            general = {
              hide_cursor = true;
              ignore_empty_input = true;
            };

            animations.enabled = true;

            background = [
              {
                monitor = "";
                color = "rgb(${color "bg0"})";
              }
            ];

            label = [
              {
                monitor = "";
                text = "$TIME";
                color = "rgb(${color "fg0"})";
                font_family = constants.fonts.ui;
                font_size = 48;
                position = "0, 80";
                halign = "center";
                valign = "center";
              }
              {
                monitor = "";
                text = "cmd[update:60000] date '+%A, %d %B'";
                color = "rgb(${color "fg1"})";
                font_family = constants.fonts.ui;
                font_size = 14;
                position = "0, 32";
                halign = "center";
                valign = "center";
              }
            ];

            input-field = [
              {
                monitor = "";
                size = "320, 52";
                position = "0, -40";
                dots_center = true;
                fade_on_empty = false;
                font_color = "rgb(${color "fg0"})";
                inner_color = "rgb(${color "bg2"})";
                outer_color = "rgb(${color "orange"})";
                check_color = "rgb(${color "orangeBright"})";
                fail_color = "rgb(${color "red"})";
                outline_thickness = 2;
                # Hyprlock does not consistently parse Pango markup in this
                # field; plain text avoids exposing literal HTML after idle.
                placeholder_text = "Password";
                shadow_passes = 0;
              }
            ];
          };
        };

        services = {
          awww.enable = true;

          hypridle = {
            enable = true;
            systemdTarget = "graphical-session.target";
            settings = {
              general = {
                after_sleep_cmd = "hyprctl dispatch dpms on";
                before_sleep_cmd = "loginctl lock-session";
                ignore_dbus_inhibit = false;
                lock_cmd = "pidof hyprlock || hyprlock";
              };
              listener = [
                {
                  timeout = 480;
                  on-timeout = "loginctl lock-session";
                }
                {
                  timeout = 600;
                  on-timeout = "hyprctl dispatch dpms off";
                  on-resume = "hyprctl dispatch dpms on";
                }
              ];
            };
          };

          hyprpolkitagent.enable = true;

          hyprsunset = {
            enable = true;
            systemdTarget = "graphical-session.target";
            settings.profile = [
              {
                time = "07:30";
                identity = true;
              }
              {
                time = "20:30";
                temperature = 4500;
                gamma = 0.9;
              }
            ];
          };
        };

        # UWSM owns the compositor lifecycle. These services therefore bind to
        # its generic graphical target and explicitly opt in to Hyprland only.
        systemd.user.services = {
          awww = {
            Unit.PartOf = [ "graphical-session.target" ];
            Service = {
              ExecCondition = hyprlandCondition;
              # A missing/unmounted wallpaper directory must not take the daemon
              # down; the leading '-' makes this best-effort in systemd.
              ExecStartPost = "-${pkgs.bash}/bin/bash ${constants.scriptDir}/show_random_wall.sh";
              # Home Manager's awww unit uses a literal `$PATH`, which systemd
              # does not expand. The post-start helper needs these exact tools.
              Environment = lib.mkForce [
                "PATH=${
                  lib.makeBinPath [
                    pkgs.awww
                    pkgs.coreutils
                    pkgs.findutils
                    pkgs.libnotify
                  ]
                }"
              ];
              Slice = "background-graphical.slice";
            };
          };

          hypridle = {
            Unit.PartOf = [ "graphical-session.target" ];
            Service = {
              ExecCondition = hyprlandCondition;
              Slice = "background-graphical.slice";
            };
          };

          hyprpolkitagent = {
            Unit.PartOf = [ "graphical-session.target" ];
            Service = {
              ExecCondition = hyprlandCondition;
              Slice = "background-graphical.slice";
            };
          };

          hyprsunset = {
            Unit.PartOf = [ "graphical-session.target" ];
            Service = {
              ExecCondition = hyprlandCondition;
              Slice = "background-graphical.slice";
            };
          };

          handy-hyprland = {
            Unit = {
              Description = "Handy transcription service for Hyprland";
              After = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Install.WantedBy = [ "graphical-session.target" ];
            Service = {
              ExecCondition = hyprlandCondition;
              ExecStart = "${pkgs.handy}/bin/handy --start-hidden";
              Restart = "on-failure";
              RestartSec = "2s";
              Slice = "app-graphical.slice";
            };
          };
        };
      };
  };
}
