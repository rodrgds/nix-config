{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.cursor-theme;
  cursorName = "Future-Cyan";
  cursorSize = 20;
in
{
  options.apps.cursor-theme = {
    enable = lib.mkEnableOption "Enable cursor-theme";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = _: {
      home.pointerCursor = {
        enable = true;
        package = pkgs.future-cyan-cursors;
        name = cursorName;
        size = cursorSize;
        gtk.enable = true;
        hyprcursor.enable = true;
        x11.enable = true;
      };
    };

    # Flatpak sandboxes cannot see Home Manager's XDG icon links by default.
    # Expose only the icon directory and keep their cursor environment aligned
    # with native Wayland, GTK, Qt, and XWayland applications.
    apps.flatpak.overrides.global = {
      Context.filesystems = [ "xdg-data/icons:ro" ];
      Environment = {
        XCURSOR_THEME = cursorName;
        XCURSOR_SIZE = toString cursorSize;
      };
    };
  };
}
