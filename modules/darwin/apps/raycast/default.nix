# Raycast - Launcher and productivity tool
# NOT available in nixpkgs, installed via Homebrew
{
  lib,
  config,
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
  };
}
