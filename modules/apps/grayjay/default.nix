{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.grayjay;
  isLinux = lib.hasSuffix "-linux" system;
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
