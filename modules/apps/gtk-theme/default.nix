{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.gtk-theme;
in
{
  options.apps.gtk-theme = {
    enable = lib.mkEnableOption "Enable GTK theme configuration";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };
        };

        gtk = {
          enable = true;
          font = {
            name = constants.fonts.ui;
            size = constants.fonts.sizes.normal;
          };
          theme = {
            package = pkgs.gruvbox-dark-gtk;
            name = "gruvbox-dark";
          };
          gtk4.theme = config.gtk.theme;
          iconTheme = {
            package = pkgs.papirus-icon-theme;
            name = "Papirus";
          };
        };
      };
  };
}
