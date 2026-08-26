# MacBook Pro M4 system-specific settings
{ config, pkgs, ... }:
{
  # Host-specific system settings
  system.defaults = {
    # Additional dock settings
    dock = {
      # Add specific dock items for this host
      persistent-apps = [
        "/Applications/Brave Browser.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/Ghostty.app"
        "/Applications/Obsidian.app"
        "/Applications/Telegram.app"
        # "/Applications/Raycast.app"
      ];
    };

    # Trackpad settings specific to MacBook
    trackpad = {
      # Trackpad settings are defined in core/system/default.nix
    };
  };
}
