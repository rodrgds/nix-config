{
  lib,
  config,
  pkgs,
  username,
  constants,
  system,
  ...
}:
let
  cfg = config.apps.ghostty;
  inherit (constants) isDarwin isLinux;
  ghosttySettings = {
    theme = "Gruvbox Dark";
    font-family = constants.fonts.primary;
    font-size = constants.fonts.sizes.large;
    window-decoration = false;
    background-opacity = constants.display.opacity;
    window-padding-x = 5;
    window-padding-y = 5;
    shell-integration = "detect";
    shell-integration-features = "cursor,sudo,title";
  };
in
{
  options.apps.ghostty = {
    enable = lib.mkEnableOption "Enable Ghostty terminal";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs and configure via home-manager
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.ghostty ];

        home-manager.users.${username} =
          { ... }:
          {
            programs.ghostty = {
              enable = true;
              settings = ghosttySettings;
            };
          };
      })
      # Darwin: Install via Homebrew and configure via home-manager (with package = null)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "ghostty" ];

        home-manager.users.${username} =
          { ... }:
          {
            programs.ghostty = {
              enable = true;
              package = null;
              settings = ghosttySettings;
            };
          };
      })
    ]
  );
}
