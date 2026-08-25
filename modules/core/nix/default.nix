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
  isVps = config.secrets.isVps or false;
in
{
  options.core.nix = {
    enable = lib.mkEnableOption "Enable Nix";
  };

  config = lib.mkIf cfg.enable (
    {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      nix.settings = {
        # Let the daemon reclaim only unreferenced store paths before a large
        # build can exhaust the filesystem. Generations and GC roots remain
        # protected, and normal operation keeps the cache untouched.
        # Keep emergency GC below the rebuild wizard's separate 64 GiB
        # preflight. A 32 GiB watermark caused every Nix command to start GC
        # whenever this machine hovered around 31 GiB free.
        min-free = 8 * 1024 * 1024 * 1024;
        max-free = 16 * 1024 * 1024 * 1024;
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
        dates = "daily";
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
          (lib.optionalAttrs (!isVps) {
            sops.secrets = {
              github_pat = { };
            };
          })
          (lib.optionalAttrs (isLinux && !isVps) {
            sops.templates."nix-conf" = {
              content = ''
                access-tokens = github.com=${config.sops.placeholder.github_pat}
              '';
              path = "${homeDir}/.config/nix/nix.conf";
            };
          })
          (lib.optionalAttrs isDarwin {
            home.activation.setupNixSecretConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                            conf_dir="${homeDir}/.config/nix"
                            mkdir -p "$conf_dir"
                            rm -f "$conf_dir/nix.conf"
                            if [ -f "${config.sops.secrets.github_pat.path}" ]; then
                              install -m 600 /dev/null "$conf_dir/nix.conf"
                              cat > "$conf_dir/nix.conf" <<EOF
              access-tokens = github.com=$(cat ${config.sops.secrets.github_pat.path})
              EOF
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
