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
    enable = lib.mkEnableOption "Enable GTK theme";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        # flexoki's default gtk.css is the light palette. Force its packaged
        # dark variant for applications and native context menus that do not
        # honor the freedesktop color-scheme preference on their own.
        home.sessionVariables.GTK_THEME = "flexoki:dark";

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "flexoki";
          };
        };

        gtk = {
          enable = true;
          font = {
            name = constants.fonts.ui;
            size = constants.fonts.sizes.normal;
          };
          theme = {
            package = pkgs.flexoki-gtk;
            name = "flexoki";
          };
          gtk4.theme = config.gtk.theme;
          gtk3.extraConfig = {
            gtk-application-prefer-dark-theme = 1;
          };
          iconTheme = {
            package = pkgs.papirus-icon-theme;
            name = "Papirus";
          };
        };
      };
  };
}
