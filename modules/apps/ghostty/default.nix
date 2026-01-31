{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.ghostty;
in
{
  options.apps.ghostty = {
    enable = lib.mkEnableOption "Enable Ghostty terminal";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ghostty ];

    home-manager.users.${username} =
      { ... }:
      {
        programs.ghostty = {
          enable = true;
          settings = {
            # Gruvbox theme (built-in)
            theme = "Gruvbox Dark";

            # Font configuration - same as alacritty
            font-family = constants.fonts.primary;
            font-size = constants.fonts.sizes.large;

            # Window settings
            window-decoration = false;
            background-opacity = constants.display.opacity;
            window-padding-x = 5;
            window-padding-y = 5;

            # Shell integration
            shell-integration = "detect";
            shell-integration-features = "cursor,sudo,title";
          };
        };
      };
  };
}
