{
  lib,
  config,
  pkgs,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.vicinae;
  inherit (constants) isLinux;
in
{
  options.apps.vicinae = {
    enable = lib.mkEnableOption "Enable Vicinae application launcher";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        # Add vicinae cachix when vicinae is enabled
        nix.settings = {
          substituters = [ "https://vicinae.cachix.org" ];
          trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
        };
      })

      {
        home-manager.users.${username} =
          { ... }:
          {
            services.vicinae = lib.mkIf isLinux {
              enable = true;
              systemd = {
                enable = true;
                autoStart = true;
                environment = {
                  USE_LAYER_SHELL = "0";
                  DISPLAY = ":0";
                  PATH = "/run/current-system/sw/bin:/home/${username}/.nix-profile/bin:/usr/bin:/bin";
                  XDG_RUNTIME_DIR = "/run/user/1000";
                  DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
                };
              };
              settings = {
                close_on_focus_loss = true;
                consider_preedit = true;
                pop_to_root_on_close = true;
                search_files_in_root = true;
                font = {
                  normal = {
                    size = constants.fonts.sizes.large;
                    family = constants.fonts.ui;
                  };
                };
                theme = {
                  dark = {
                    name = "gruvbox-custom";
                    icon_theme = "Papirus";
                  };
                };
                launcher_window = {
                  opacity = constants.display.opacity;
                };
                extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
                  nix
                  vscode-recents
                  port-killer
                  it-tools
                ];
              };
            };

            home.file.".local/share/vicinae/themes/gruvbox-custom.toml".text = ''
              [meta]
              version = 1
              name = "Gruvbox Custom"
              description = "Custom Gruvbox dark theme for vicinae"
              variant = "dark"
              inherits = "vicinae-dark"

              [colors.core]
              background = "${constants.colors.bg0}"
              foreground = "${constants.colors.fg0}"
              secondary_background = "${constants.colors.bg1}"
              border = "${constants.colors.bg2}"
              accent = "${constants.colors.orange}"

              [colors.accents]
              blue = "${constants.colors.blue}"
              green = "${constants.colors.green}"
              magenta = "${constants.colors.magenta}"
              orange = "${constants.colors.orange}"
              purple = "${constants.colors.magenta}"
              red = "${constants.colors.red}"
              yellow = "${constants.colors.yellow}"
              cyan = "${constants.colors.cyan}"

              [colors.input]
              background = "${constants.colors.bg1}"
              foreground = "${constants.colors.fg0}"
              border = "${constants.colors.bg2}"
              border_focus = "${constants.colors.orange}"
              placeholder = "${constants.colors.fg2}"

              [colors.list]
              background = "${constants.colors.bg0}"
              foreground = "${constants.colors.fg0}"
              selected_background = "${constants.colors.bg2}"
              selected_foreground = "${constants.colors.orangeBright}"
              hover_background = "${constants.colors.bg2}"
              hover_foreground = "${constants.colors.fg0}"

              [colors.scrollbar]
              track = "${constants.colors.bg1}"
              thumb = "${constants.colors.fg2}"
              thumb_hover = "${constants.colors.fg1}"
            '';
          };
      }
    ]
  );
}
