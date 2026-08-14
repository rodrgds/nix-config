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
        # Use a standalone dark theme identity instead of GTK's optional
        # `:dark` variant. Some GTK3/GTK4 consumers otherwise load flexoki's
        # light default stylesheet despite the dark color-scheme preference.
        home.sessionVariables.GTK_THEME = "flexoki-dark";

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "flexoki-dark";
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
            name = "flexoki-dark";
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
