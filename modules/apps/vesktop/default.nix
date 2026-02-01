{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.vesktop;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.vesktop = {
    enable = lib.mkEnableOption "Enable Vesktop";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vesktop ];
      })
    ]
  );
}
