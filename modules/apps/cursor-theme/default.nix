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
    enable = lib.mkEnableOption "Enable cursor-theme";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = _: {
      home.pointerCursor = {
        enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Amber";
        size = 28;
        gtk.enable = true;
        x11.enable = true;
      };

      # Hyprland's native cursor format avoids the fallback/default cursor in
      # compositor-owned surfaces. GTK and XWayland keep the matching amber
      # Bibata theme above.
      home.packages = [ pkgs.rose-pine-hyprcursor ];
      home.sessionVariables = {
        HYPRCURSOR_THEME = "rose-pine-hyprcursor";
        HYPRCURSOR_SIZE = 28;
        XCURSOR_THEME = "Bibata-Modern-Amber";
        XCURSOR_SIZE = 28;
      };
    };
  };
}
