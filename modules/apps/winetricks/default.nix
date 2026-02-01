{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.winetricks;
  isLinux = lib.hasSuffix "-linux" system;
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
