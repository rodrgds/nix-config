{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.flameshot;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.flameshot = {
    enable = lib.mkEnableOption "Enable Flameshot";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.flameshot ];
      })
    ]
  );
}
