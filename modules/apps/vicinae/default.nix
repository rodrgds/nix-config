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
    enable = lib.mkEnableOption "Enable Vicinae";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        nix.settings = {
          substituters = [ "https://vicinae.cachix.org" ];
          trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
        };
      })

      {
        home-manager.users.${username} = _: {
          programs.vicinae = lib.mkIf isLinux {
            enable = true;
            package = pkgs.vicinae;

            systemd = {
              enable = true;
              autoStart = true;
            };

            useLayerShell = true;

            settings = {
              closeOnFocusLoss = true;
              considerPreedit = true;
              popToRootOnClose = true;
              rootSearch.searchFiles = true;
              window.opacity = constants.display.opacity;
              font = {
                normal = constants.fonts.ui;
                size = constants.fonts.sizes.large;
              };
              theme = {
                name = "flexoki-custom";
                iconTheme = "Papirus";
              };
            };

            themes = {
              "flexoki-custom" = {
                meta = {
                  version = 1;
                  name = "Flexoki Custom";
                  description = "Custom Flexoki dark theme for vicinae";
                  variant = "dark";
                  inherits = "vicinae-dark";
                };
                colors = {
                  core = {
                    background = constants.colors.bg0;
                    foreground = constants.colors.fg0;
                    secondary_background = constants.colors.bg1;
                    border = constants.colors.bg2;
                    accent = constants.colors.orange;
                  };
                  accents = {
                    blue = constants.colors.blue;
                    green = constants.colors.green;
                    magenta = constants.colors.magenta;
                    orange = constants.colors.orange;
                    purple = constants.colors.magenta;
                    red = constants.colors.red;
                    yellow = constants.colors.yellow;
                    cyan = constants.colors.cyan;
                  };
                  list.item = {
                    selection = {
                      background = {
                        name = constants.colors.bg2;
                        opacity = 0.7;
                      };
                      secondary_background = constants.colors.bg2;
                      foreground = constants.colors.orangeBright;
                    };
                    hover = {
                      background = constants.colors.bg2;
                      foreground = constants.colors.fg0;
                    };
                  };
                };
              };
            };

            extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
              nix
              vscode-recents
              port-killer
              it-tools
              protondb-search
              iconify
            ];
          };

          systemd.user.services.vicinae = lib.mkIf isLinux {
            Unit.After = [ "graphical-session.target" ];
            Service = {
              Environment = [
                "PATH=/run/current-system/sw/bin:/home/${username}/.nix-profile/bin:/usr/bin:/bin"
                "XDG_DATA_DIRS=/run/current-system/sw/share:/var/lib/flatpak/exports/share:/home/${username}/.local/share/flatpak/exports/share:/home/${username}/.local/share"
              ];
              KillMode = lib.mkForce "control-group";
            };
          };
        };
      }
    ]
  );
}
