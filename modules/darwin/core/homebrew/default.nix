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
      taps = [
        "homebrew/cask"
        "homebrew/cask-versions"
        "homebrew/services"
        "nikitabobko/tap" # For Aerospace
        "FelixKratz/formulae" # For JankyBorders
      ];

      # Brews (CLI tools installed via Homebrew)
      brews = [
        "mas" # Mac App Store CLI
      ];

      # Darwin-specific Homebrew settings
      caskArgs = {
        no_quarantine = true;
      };
    };
  };
}
