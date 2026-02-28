{ lib, config, ... }:
let
  cfg = config.core.nix;
in
{
  options.core.nix = {
    enable = lib.mkEnableOption "Enable Nix configuration";
  };

  config = lib.mkIf cfg.enable {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    nix.settings = {
      substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nix.settings.auto-optimise-store = true;

    programs.nix-ld.enable = true;

    nixpkgs.config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "qtwebengine-5.15.19" ];
    };
  };
}
