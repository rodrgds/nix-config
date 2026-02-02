# Raycast - Launcher and productivity tool
# NOT available in nixpkgs, installed via Homebrew
{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.raycast;
in
{
  options.apps.raycast = {
    enable = lib.mkEnableOption "Enable Raycast launcher";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "raycast" ];

    # Disable Spotlight keyboard shortcut so Raycast can use Ctrl+Space
    system.defaults = {
      # Disable Cmd+Space shortcut for Spotlight
      NSGlobalDomain = {
        # This disables the default Spotlight shortcut
        # Raycast will need to be configured manually to use Ctrl+Space
      };
    };
  };
}
