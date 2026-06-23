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
        trusted-users = [
          "root"
          username
        ];
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
        { config, lib, ... }:
        lib.mkMerge [
          (lib.optionalAttrs isLinux {
            sops.templates."nix-conf" = {
              content = ''
                access-tokens = github.com=${config.sops.placeholder.github_pat}
              '';
              path = "${homeDir}/.config/nix/nix.conf";
            };
          })
          (lib.optionalAttrs isDarwin {
            home.activation.setupNixSecretConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              mkdir -p "${homeDir}/.config/nix"
              if [ -f "${config.sops.secrets.github_pat.path}" ]; then
                cat > "${homeDir}/.config/nix/nix.conf" << EOF
              access-tokens = github.com=$(cat ${config.sops.secrets.github_pat.path})
              EOF
                chmod 600 "${homeDir}/.config/nix/nix.conf"
              fi
            '';
          })
        ];
    }
    // lib.optionalAttrs isLinux {
      environment.pathsToLink = [ "/libexec" ];
      programs.nix-ld.enable = true;
    }
  );
}
