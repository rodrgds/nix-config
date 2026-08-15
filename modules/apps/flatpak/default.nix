{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.flatpak;
  inherit (constants) isLinux;

  packageType = with lib.types; either str (attrsOf anything);
  remoteType = lib.types.submodule (_: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "flathub";
        description = "Flatpak remote name.";
      };

      location = lib.mkOption {
        type = lib.types.str;
        default = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        description = "Flatpak remote repository URL.";
      };

      gpg-import = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional GPG key file to import for this remote.";
      };

      args = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional extra arguments passed to flatpak remote-add.";
      };
    };
  });
in
{
  options.apps.flatpak = {
    enable = lib.mkEnableOption "Enable Flatpak";

    packages = lib.mkOption {
      type = lib.types.listOf packageType;
      default = [ ];
      example = [
        "com.spotify.Client"
        { appId = "com.github.tchx84.Flatseal"; }
      ];
      description = ''
        Flatpak applications to install system-wide through nix-flatpak.

        Entries may be simple Flathub app IDs or nix-flatpak package attribute
        sets, including bundle-based installs such as:
        `{ appId = "org.example.App"; bundle = "/nix/store/.../app.flatpak"; sha256 = "..."; }`.
      '';
    };

    remotes = lib.mkOption {
      type = lib.types.listOf remoteType;
      default = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      description = "Flatpak remotes managed declaratively.";
    };

    installFlatseal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Flatseal for GUI Flatpak permission management.";
    };

    update = {
      onActivation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Update Flatpaks during system activation.";
      };

      auto = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable periodic Flatpak updates.";
        };

        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "systemd timer calendar expression for automatic Flatpak updates.";
        };
      };
    };

    uninstallUnmanaged = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Uninstall system Flatpaks and remotes not declared by this module.";
    };

    uninstallUnused = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run `flatpak uninstall --unused` after reconciliation.";
    };

    overrides = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.attrsOf (
          lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str))
        )
      );
      default = { };
      description = "Flatpak override configuration managed by nix-flatpak.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs isLinux {
      services.flatpak = {
        enable = true;
        inherit (cfg)
          remotes
          overrides
          uninstallUnmanaged
          uninstallUnused
          ;
        packages = lib.optionals cfg.installFlatseal [ "com.github.tchx84.Flatseal" ] ++ cfg.packages;

        update = {
          inherit (cfg.update) onActivation auto;
        };
      };

      apps.xdg-portals.enable = lib.mkDefault true;

      environment.systemPackages = [
        pkgs.flatpak
        pkgs.xdg-utils
      ];

      environment.extraInit = ''
        export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:$XDG_DATA_DIRS"
      '';
    }
  );
}
