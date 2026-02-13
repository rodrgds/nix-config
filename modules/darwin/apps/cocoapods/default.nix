# CocoaPods - Dependency manager for Cocoa projects
# Installed via Homebrew on Darwin
{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.cocoapods;
in
{
  options.apps.cocoapods = {
    enable = lib.mkEnableOption "Enable CocoaPods";
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [ "cocoapods" ];
  };
}
