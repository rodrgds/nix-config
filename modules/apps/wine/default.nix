{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.wine;
  isLinux = lib.hasSuffix "-linux" system;
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
