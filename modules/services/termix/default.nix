# Termix - Web-based terminal emulator with remote desktop access
# https://github.com/lukegus/termix
#
# Termix provides browser-based terminal and remote desktop access via Guacamole.
# It requires two containers: guacd (the Guacamole daemon) and termix (the web UI).
#
# FIRST-TIME SETUP:
#   After deployment, Termix should be accessible at https://termix.rgo.pt
#   Configure connections through the web interface.
#
# NO SECRETS REQUIRED:
#   Termix doesn't require any pre-configured secrets for basic operation.
#
{
  config,
  lib,
  ...
}:
let
  cfg = config.vps.termix;

  termixPort = 8080;
in
{
  options.vps.termix = {
    enable = lib.mkEnableOption "Termix web-based terminal and remote desktop";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "termix.rgo.pt";
      description = "Domain for Termix web interface";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/termix 0750 root root -"
      "d /var/lib/termix/data 0750 1000 1000 -"
    ];

    # guacd - Guacamole daemon (internal, no external port needed)
    # Note: guacd uses Guacamole protocol (not HTTP), so no HTTP health check
    virtualisation.oci-containers.containers.guacd = {
      image = "guacamole/guacd:latest";

      extraOptions = [
        "--network=podman"
      ];
    };

    # Termix web application
    virtualisation.oci-containers.containers.termix = {
      image = "ghcr.io/lukegus/termix:latest";

      environment = {
        PORT = "8080";
      };

      volumes = [
        "/var/lib/termix/data:/app/data"
      ];

      ports = [
        "127.0.0.1:${toString termixPort}:8080"
      ];

      dependsOn = [ "guacd" ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:8080 || exit 1"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
        "--health-start-period=10s"
      ];
    };

    # Caddy reverse proxy configuration
    vps.caddy.internalPorts.${cfg.domain} = termixPort;
  };
}
