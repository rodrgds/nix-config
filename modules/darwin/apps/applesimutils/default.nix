# AppleSimUtils - Utilities for iOS Simulator automation
# Installed via Homebrew on Darwin
{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.applesimutils;
in
{
  options.apps.applesimutils = {
    enable = lib.mkEnableOption "Enable AppleSimUtils for iOS Simulator automation";
  };

  config = lib.mkIf cfg.enable {
    # Tap the wix/brew repository first
    homebrew.taps = [ "wix/brew" ];
    
    # Install applesimutils
    homebrew.brews = [ "applesimutils" ];
  };
}