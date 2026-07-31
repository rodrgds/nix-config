{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.nodejs;
in
{
  options.apps.nodejs = {
    enable = lib.mkEnableOption "Enable Node.js";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nodejs
      pkgs.glib
      pkgs.libglvnd
    ];
  };
}
