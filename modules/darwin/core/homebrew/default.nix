# Darwin core Homebrew configuration
# Provides the Homebrew infrastructure (taps, settings)
# Actual app installations are in hosts/rgo-laptop/homebrew.nix
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.darwin.core.homebrew;
in
{
  options.darwin.core.homebrew = {
    enable = lib.mkEnableOption "Enable Homebrew integration";
  };

  config = lib.mkIf cfg.enable {
    # Homebrew configuration
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "zap";
        upgrade = true;
      };

      # Taps to add
      # Note: homebrew/cask, homebrew/cask-versions, and homebrew/services
      # are deprecated - casks and services are now built into Homebrew core
      taps = [
        "nikitabobko/tap" # For Aerospace
        "FelixKratz/formulae" # For JankyBorders
        "gromgit/fuse" # For sshfs-mac
      ];

      # Brews (CLI tools installed via Homebrew)
      brews = [
        "mas" # Mac App Store CLI
      ];

    };
  };
}
