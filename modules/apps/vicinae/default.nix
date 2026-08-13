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
  inherit (constants) isDarwin isLinux;
  vicinaePackage = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  sharedExtensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
    nix
    vscode-recents
    port-killer
    it-tools
    protondb-search
    iconify
  ];

  sharedSettings =
    lib.recursiveUpdate
      {
        close_on_focus_loss = true;
        consider_preedit = true;
        favorites = [
          "@ShyAssassin/vicinae-extension-vscode-recents-0:open-recents"
          "clipboard:history"
          "@nikbpetrov/vicinae-extension-it-tools-0:it-tools-command"
          "@LuggaPugga/vicinae-extension-port-killer-0:port-killer"
          "@marcjulian/store.raycast.obsidian:dailyNoteCommand"
        ];
        pop_to_root_on_close = true;
        search_files_in_root = true;
        launcher_window.opacity = constants.display.opacity;
        font.normal = {
          family = constants.fonts.ui;
          size = constants.fonts.sizes.large;
        };
        theme = {
          light = {
            name = "flexoki-custom";
            icon_theme = if isLinux then "Papirus" else "auto";
          };
          dark = {
            name = "flexoki-custom";
            icon_theme = if isLinux then "Papirus" else "auto";
          };
        };
      }
      (
        lib.optionalAttrs isLinux {
          launcher_window.layer_shell.enabled = false;
        }
      );

  sharedTheme = {
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
in
{
  options.apps.vicinae = {
    enable = lib.mkEnableOption "Enable Vicinae";
  };

  config = lib.mkMerge [
    # The upstream NixOS module enables its privileged input server by
    # default. Tie it to this repo's opt-in flag so headless hosts do not pull
    # Vicinae into their system closure merely because the module is imported.
    (lib.optionalAttrs isLinux {
      programs.vicinae.input-server.enable = cfg.enable;
    })

    (lib.mkIf cfg.enable (
      lib.mkMerge [
        (lib.optionalAttrs isDarwin {
          # The macOS app ships as a notarized Apple Silicon cask. Homebrew
          # also links its CLI, which keeps the launcher bindings portable.
          homebrew.casks = [ "vicinae" ];
        })

        (lib.optionalAttrs isLinux {
          nix.settings = {
            substituters = [ "https://vicinae.cachix.org" ];
            trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
          };

          programs.vicinae.input-server.package = vicinaePackage;
        })

        {
          home-manager.users.${username} =
            _:
            lib.mkMerge [
              (lib.optionalAttrs isLinux {
                programs.vicinae = {
                  enable = true;
                  package = vicinaePackage;

                  systemd = {
                    enable = true;
                    autoStart = true;
                  };

                  settings = sharedSettings;
                  themes."flexoki-custom" = sharedTheme;
                  extensions = sharedExtensions;
                };

                systemd.user.services.vicinae = {
                  Unit.After = [ "graphical-session.target" ];
                  Service = {
                    Environment = [
                      "PATH=${vicinaePackage}/libexec/vicinae:/run/current-system/sw/bin:/home/${username}/.nix-profile/bin:/usr/bin:/bin"
                      "XDG_DATA_DIRS=/run/current-system/sw/share:/var/lib/flatpak/exports/share:/home/${username}/.local/share/flatpak/exports/share:/home/${username}/.local/share"
                    ];
                    KillMode = lib.mkForce "control-group";
                  };
                };
              })

              (lib.optionalAttrs isDarwin {
                xdg.configFile."vicinae/settings.json" = {
                  source = jsonFormat.generate "vicinae-settings" sharedSettings;
                  force = true;
                };
                xdg.dataFile = {
                  "vicinae/themes/flexoki-custom.toml".source =
                    tomlFormat.generate "vicinae-flexoki-custom-theme" sharedTheme;
                }
                // builtins.listToAttrs (
                  map (extension: {
                    name = "vicinae/extensions/${extension.name}";
                    value.source = extension;
                  }) sharedExtensions
                );
              })
            ];
        }
      ]
    ))
  ];
}
