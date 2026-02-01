{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.darktable;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.darktable = {
    enable = lib.mkEnableOption "Enable Darktable";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.darktable ];
      })
    ]
  );
}
