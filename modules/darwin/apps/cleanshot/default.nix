# CleanShot X - Screenshot tool for macOS
# NOT available in nixpkgs, installed via Homebrew
# Replaces Flameshot on macOS
{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.cleanshot;
in
{
  options.apps.cleanshot = {
    enable = lib.mkEnableOption "Enable CleanShot X screenshot tool";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "cleanshot" ];
  };
}
