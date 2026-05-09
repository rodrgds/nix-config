{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.davinci-resolve;
  inherit (constants) isLinux;
in
{
  options.apps.davinci-resolve = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve Studio";

    packageMode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "frozen"
      ];
      default = "managed";
      description = ''
        How DaVinci Resolve is installed. "managed" keeps the custom Nix package
        in the system closure. "frozen" keeps using a previously built executable
        pinned through a persistent GC root, avoiding normal rebuild churn.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        core.frozen-packages.packages.davinci-resolve = {
          mode = cfg.packageMode;
          package = pkgs.davinci-resolve-studio;
          command = "davinci-resolve-studio";
          executablePath = "/bin/davinci-resolve-studio";
          rootName = "rgo-davinci-resolve";
        };
      })
    ]
  );
}
