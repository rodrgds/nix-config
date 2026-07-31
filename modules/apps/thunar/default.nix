{
  lib,
  config,
  pkgs,
  username,
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
    environment.systemPackages = [
      pkgs.xarchiver
      pkgs.thunar
      pkgs.tumbler
      pkgs.thunar-archive-plugin
    ];

    home-manager.users.${username} = _: {
      # Thunar is configured through dconf/gsettings
    };
  };
}
