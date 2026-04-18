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
    };

    networking.firewall = {
      enable = false;
      trustedInterfaces = [ "tailscale0" ];
    };

    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      extraUpFlags = [ "--accept-dns=true" ];
    };
  };
}
