{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.darktable;
  inherit (constants) isLinux;
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
