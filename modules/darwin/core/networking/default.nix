{
  lib,
  config,
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
    homebrew.casks = lib.mkIf cfg.tailscale.enable [ "tailscale-app" ];

    # Hostname is set in the host-specific configuration
  };
}
