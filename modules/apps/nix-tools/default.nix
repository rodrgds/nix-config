{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.nix-tools;
  nixToolPackages = [
    pkgs.nixd # Nix language server
    pkgs.nil # Alternative Nix language server
    pkgs.nurl # Generate Nix fetcher calls from URLs
    pkgs.nix-init # Scaffold Nix packages from URLs
    pkgs.statix # Lint Nix code
    pkgs.nixfmt # Format Nix files
    pkgs.home-manager # Home-manager CLI
  ];
in
{
  options.apps.nix-tools = {
    enable = lib.mkEnableOption "Enable nix-tools";
  };

  config = lib.mkIf cfg.enable {
    # Enable individual sub-modules
    apps.comma.enable = true;
    apps.nh.enable = true;
    core.angrr.enable = true;

    # Nix-specific development tools
    environment.systemPackages = nixToolPackages;

    # Keep GUI-launched editors able to resolve Nix tooling from the user profile,
    # especially on macOS where Homebrew apps are often started outside a shell.
    home-manager.users.${username} = {
      home.packages = nixToolPackages;
    };
  };
}
