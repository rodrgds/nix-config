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
    enable = lib.mkEnableOption "Enable networking";

    tailscale = {
      enable = lib.mkEnableOption "Enable Tailscale";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install Tailscale via Homebrew when enabled
    homebrew.casks = lib.mkIf cfg.tailscale.enable [ "tailscale-app" ];

    # Hostname is set in the host-specific configuration
  };
}
