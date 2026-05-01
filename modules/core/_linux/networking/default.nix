{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.core.networking;
in
{
  options.core.networking = {
    enable = lib.mkEnableOption "Enable networking configuration";
    tailscale.acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether this host should accept DNS settings pushed by Tailscale.";
    };
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
      extraUpFlags = [ "--accept-dns=${lib.boolToString cfg.tailscale.acceptDns}" ];
    };

    # Tailscale persists DNS preferences in its own state, so re-apply the
    # declarative accept-dns setting after the daemon starts.
    systemd.services.tailscale-apply-dns-settings = {
      description = "Apply persisted Tailscale DNS preferences";
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
          exit 0
        fi

        ${pkgs.tailscale}/bin/tailscale set --accept-dns=${lib.boolToString cfg.tailscale.acceptDns}
      '';
    };
  };
}
