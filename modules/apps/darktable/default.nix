{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.darktable;
in
{
  options.apps.darktable = {
    enable = lib.mkEnableOption "Enable Darktable";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.darktable ];
  };
}
