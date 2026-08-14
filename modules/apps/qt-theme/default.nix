{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.qt-theme;
in
{
  options.apps.qt-theme = {
    enable = lib.mkEnableOption "Enable the Flexoki Qt theme";
  };

  config = lib.mkIf (cfg.enable && constants.isLinux) {
    home-manager.users.${username}.qt = {
      enable = true;

      # Qt's GTK 3 platform integration consumes the same Flexoki GTK theme,
      # dark preference, fonts, and icon theme as native GTK applications.
      # This keeps Qt 5/6 applications visually aligned without maintaining a
      # second, subtly divergent palette in qt5ct/qt6ct.
      platformTheme.name = "gtk3";
    };
  };
}
