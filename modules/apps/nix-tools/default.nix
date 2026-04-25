{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.nix-tools;
in
{
  options.apps.nix-tools = {
    enable = lib.mkEnableOption "Enable nix-tools (nh, comma, angrr, nurl, nix-init, statix, nil, home-manager, nixfmt)";
  };

  config = lib.mkIf cfg.enable {
    # Enable individual sub-modules
    apps.comma.enable = true;
    apps.nh.enable = true;
    core.angrr.enable = true;

    # Nix-specific development tools
    environment.systemPackages = [
      pkgs.nil # Nix language server
      pkgs.nurl # Generate Nix fetcher calls from URLs
      pkgs.nix-init # Scaffold Nix packages from URLs
      pkgs.statix # Lint Nix code
      pkgs.nixfmt # Format Nix files
      pkgs.home-manager # Home-manager CLI
    ];
  };
}
