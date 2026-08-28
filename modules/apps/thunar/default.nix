{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.thunar;
in
{
  options.apps.thunar = {
    enable = lib.mkEnableOption "Enable Thunar";
  };

  config = lib.mkIf cfg.enable {
    programs.thunar = {
      enable = true;
      plugins = [ pkgs.thunar-archive-plugin ];
    };

    environment.systemPackages = [
      pkgs.file-roller
      pkgs.tumbler
    ];
  };
}
