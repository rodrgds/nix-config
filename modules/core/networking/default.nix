{ lib, config, ... }:
let
  cfg = config.core.networking;
in
{
  options.core.networking = {
    enable = lib.mkEnableOption "Enable networking configuration";
  };

  config = lib.mkIf cfg.enable {
    networking.useDHCP = false;
    networking.networkmanager.enable = true;
    networking.dhcpcd.extraConfig = "nohook resolv.conf";

    services.resolved = {
      enable = true;
      settings = {
        Resolve = {
          DNSSEC = "true";
          Domains = [ "~." ];
          FallbackDNS = [
            "1.1.1.1"
            "1.0.0.1"
          ];
          DNSOverTLS = "false";
        };
      };
    };

    networking.firewall = {
      enable = false;
      trustedInterfaces = [ "tailscale0" ];
    };

    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };
}
