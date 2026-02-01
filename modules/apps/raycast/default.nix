# Raycast - Launcher and productivity tool
# NOT available in nixpkgs, installed via Homebrew
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.raycast;
in
{
  options.apps.raycast = {
    enable = lib.mkEnableOption "Enable Raycast launcher";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Only available on Darwin via Homebrew
      (lib.optionalAttrs (config.nixpkgs.hostPlatform.isDarwin or false) {
        homebrew.casks = [ "raycast" ];
      })
      # Note: Not available for Linux (use rofi or similar)
    ]
  );
}
