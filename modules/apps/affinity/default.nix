{
  lib,
  config,
  pkgs,
  inputs,
  constants,
  ...
}:
let
  cfg = config.apps.affinity;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.affinity = {
    enable = lib.mkEnableOption "Enable Affinity";

    packageMode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "frozen"
      ];
      default = "managed";
      description = ''
        "managed" installs Affinity in the system closure. "frozen" keeps a
        persistent GC root to the already installed Affinity build and only
        installs a lightweight wrapper.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        nix.settings = {
          substituters = [ "https://cache.garnix.io" ];
          trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
        };

        core.frozen-packages.packages.affinity-v3 = {
          mode = cfg.packageMode;
          package = inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.v3;
          command = "affinity-v3";
          executablePath = "/bin/affinity-v3";
          rootName = "rgo-affinity-v3";
        };
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "affinity"
        ];
      })
    ]
  );
}
