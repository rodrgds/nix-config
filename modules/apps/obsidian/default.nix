{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.obsidian;
in
{
  options.apps.obsidian = {
    enable = lib.mkEnableOption "Enable Obsidian";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.obsidian ];
  };
}
