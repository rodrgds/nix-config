{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.core.nix;
  inherit (constants) isLinux isDarwin homeDir;
in
{
  options.core.nix = {
    enable = lib.mkEnableOption "Enable Nix configuration";
  };

  config = lib.mkIf cfg.enable (
    {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      nix.settings = {
        substituters = [
          "https://cache.nixos.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ];
      };

      nix.gc = {
        automatic = true;
        options = "--delete-older-than 15d";
      }
      // lib.optionalAttrs isLinux {
        dates = "weekly";
      }
      // lib.optionalAttrs isDarwin {
        interval = {
          Weekday = 0;
        };
      };

      nix.optimise.automatic = true;

      nixpkgs.config = {
        allowUnfree = true;
        permittedInsecurePackages = [ "qtwebengine-5.15.19" ];
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          sops.templates."nix-conf" = {
            content = ''
              access-tokens = github.com=${config.sops.placeholder.github_pat}
            '';
            path = "${homeDir}/.config/nix/nix.conf";
          };
        };
    }
    // lib.optionalAttrs isLinux {
      environment.pathsToLink = [ "/libexec" ];
      programs.nix-ld.enable = true;
    }
  );
}
