# Glances - system monitoring
# https://github.com/nicolargo/glances
#
# Runs the web server mode (--web) so the dashboard is accessible from any
# browser on the Tailscale network. No public domain or Caddy route - only
# reachable via Tailscale IP.
#
# Usage:
#   http://<tailscale-ip>:61208
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.glances;
in
{
  options.vps.glances = {
    enable = lib.mkEnableOption "Enable Glances system monitoring";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind the web server to. Set to the Tailscale IP for remote access.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 61208;
      description = "Web server port";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bindAddress != "0.0.0.0" && cfg.bindAddress != "::";
        message = "Glances should not be exposed on all interfaces. Bind it to localhost or the Tailscale IP.";
      }
    ];

    # Glances needs a writable home for its config/state cache.
    systemd.tmpfiles.rules = [
      "d /var/lib/glances 0755 glances glances -"
    ];

    users.users.glances = {
      isSystemUser = true;
      group = "glances";
      home = "/var/lib/glances";
      createHome = true;
    };
    users.groups.glances = { };

    systemd.services.glances = {
      description = "Glances system monitoring";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "glances";
        Group = "glances";
        WorkingDirectory = "/var/lib/glances";

        ExecStart = ''
          ${pkgs.glances}/bin/glances \
            --web \
            --bind ${cfg.bindAddress} \
            --port ${toString cfg.port}
        '';

        Restart = "on-failure";
        RestartSec = 5;

        # Hardening - Glances only reads /proc and /sys.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = false; # needs /proc/sys
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        SystemCallFilter = [ "@system-service" ];
        SystemCallArchitectures = "native";
      };
    };

    # Only expose on Tailscale interface.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];
  };
}
