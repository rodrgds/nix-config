{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.gimp;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.gimp = {
    enable = lib.mkEnableOption "Enable GIMP";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.gimp ];
      })
    ]
  );
}
