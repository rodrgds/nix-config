{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.grayjay;
  inherit (constants) isLinux;
in
{
  options.apps.grayjay = {
    enable = lib.mkEnableOption "Enable Grayjay";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.grayjay ];
      })
    ]
  );
}
