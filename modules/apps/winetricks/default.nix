{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.winetricks;
  inherit (constants) isLinux;
in
{
  options.apps.winetricks = {
    enable = lib.mkEnableOption "Enable Winetricks";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.winetricks ];
      })
    ]
  );
}
