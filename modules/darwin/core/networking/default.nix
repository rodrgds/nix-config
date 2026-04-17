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

    adguard = {
      enable = lib.mkEnableOption "Use AdGuard Home DNS server on macOS";

      dnsServer = lib.mkOption {
        type = lib.types.str;
        default = "dns.rgo.pt";
        description = "Primary DNS server for known macOS network services";
      };

      fallbackDns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        description = "Fallback DNS servers after AdGuard Home";
      };
    };

    tailscale = {
      enable = lib.mkEnableOption "Enable Tailscale VPN via Homebrew";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install Tailscale via Homebrew when enabled
    homebrew.casks = lib.mkIf cfg.tailscale.enable [ "tailscale-app" ];

    networking = lib.mkIf cfg.adguard.enable {
      knownNetworkServices = [
        "Wi-Fi"
        "Thunderbolt Bridge"
        "USB 10/100/1000 LAN"
      ];

      dns = [ cfg.adguard.dnsServer ] ++ cfg.adguard.fallbackDns;
    };

    # Hostname is set in the host-specific configuration
  };
}
