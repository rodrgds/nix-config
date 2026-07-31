{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.gimp;
  inherit (constants) isLinux;
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
