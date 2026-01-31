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
    enable = lib.mkEnableOption "Enable Thunar file manager";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xarchiver
      thunar
      tumbler
      thunar-archive-plugin
    ];

    home-manager.users.${username} =
      { ... }:
      {
        # Thunar is configured through dconf/gsettings
      };
  };
}
