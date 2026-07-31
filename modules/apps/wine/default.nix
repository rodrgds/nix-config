{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.wine;
  inherit (constants) isLinux;
in
{
  options.apps.wine = {
    enable = lib.mkEnableOption "Enable Wine";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.wine ];
      })
    ]
  );
}
