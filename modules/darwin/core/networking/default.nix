{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.darwin.core.networking;
in
{
  options.darwin.core.networking = {
    enable = lib.mkEnableOption "Enable Darwin networking configuration";

    tailscale = {
      enable = lib.mkEnableOption "Enable Tailscale VPN via Homebrew";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install Tailscale via Homebrew when enabled
    homebrew.casks = lib.mkIf cfg.tailscale.enable [ "tailscale" ];

    # DNS settings can be configured if needed
    # networking.dns = [ "1.1.1.1" "1.0.0.1" ];

    # Hostname is set in the host-specific configuration
  };
}
