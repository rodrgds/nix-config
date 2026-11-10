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
  cfg = config.core.nix;
  inherit (constants) isLinux isDarwin homeDir;
  isVps = config.secrets.isVps or false;
  # Extra caches cost a lookup for every missing path, so list only caches
  # whose builds this configuration actually uses. Vicinae's Linux build comes
  # from its own flake; everything else is on cache.nixos.org.
  workstationCaches = lib.optionals (!isVps && isLinux && config.apps.vicinae.enable) [
    {
      url = "https://vicinae.cachix.org";
      key = "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=";
    }
  ];
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
        # Trusted users have root-equivalent access. Keep normal build access
        # separate, and preserve VPS deployment trust until signed transfers
        # and remote builds have been verified end to end.
        trusted-users = [ "root" ] ++ lib.optional isVps username;
        allowed-users = lib.mkDefault [ "*" ];
        trusted-substituters = map (cache: cache.url) workstationCaches;
        require-sigs = true;
        accept-flake-config = false;
        substituters = [ "https://cache.nixos.org" ] ++ map (cache: cache.url) workstationCaches;
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ]
        ++ map (cache: cache.key) workstationCaches;
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

      # Pin this generation's flake inputs so the weekly GC keeps them. Without
      # a root, GC deletes their sources (about 1 GiB, mostly nixpkgs) and the
      # next rebuild downloads them again before it can evaluate (~30s). `self`
      # stays out so editing the checkout alone never changes the system.
      environment.etc = lib.mkMerge [
        (lib.mkIf (!isVps) {
          "nix/flake-inputs".source = pkgs.linkFarm "flake-inputs" (
            lib.mapAttrs (_: input: input.outPath) (removeAttrs inputs [ "self" ])
          );
        })
        # nix-darwin restarts the daemon when /etc/nix/machines differs from
        # the running system's copy, and diff treats two missing files as
        # different, so every activation restarted it. An empty file (no
        # remote builders) keeps the daemon running across rebuilds.
        (lib.mkIf isDarwin { "nix/machines".text = ""; })
      ];

      nix.optimise = {
        automatic = true;
      }
      // lib.optionalAttrs isLinux {
        dates = "weekly";
        # Optimisation is maintenance, not a boot prerequisite. Skip a missed
        # weekly run instead of saturating storage shortly after startup.
        persistent = false;
      };

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
