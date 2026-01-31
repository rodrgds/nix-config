{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.cursor-theme;
in
{
  options.apps.cursor-theme = {
    enable = lib.mkEnableOption "Enable cursor theme configuration";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { ... }:
      {
        gtk.cursorTheme = {
          package = pkgs.apple-cursor;
          name = "macOS";
          size = 28;
        };
      };
  };
}
