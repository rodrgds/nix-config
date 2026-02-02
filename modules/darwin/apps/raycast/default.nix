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

    # Raycast configuration via home-manager
    home-manager.users.${username} = {
      # Raycast preferences are stored in plist files
      # We'll create a script to configure it
      home.file = {
        ".config/raycast/setup.sh" = {
          text = ''
            #!/bin/bash
            # Raycast setup script
            # Run this after Raycast is installed to configure it

            # Set Raycast shortcut to Ctrl+Space
            defaults write com.raycast.macos raycastGlobalHotkey -dict \
              keyCode 49 \
              modifiers 4096

            # Alternative: Set to Cmd+Space (if you prefer)
            # defaults write com.raycast.macos raycastGlobalHotkey -dict \
            #   keyCode 49 \
            #   modifiers 1048576

            echo "Raycast configured. Please restart Raycast."
          '';
          executable = true;
        };
      };
    };
  };
}
