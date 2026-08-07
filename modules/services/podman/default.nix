# Podman container runtime for VPS
# Uses virtualisation.oci-containers for declarative container management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.podman;
in
{
  options.services.podman = {
    enable = lib.mkEnableOption "Enable Podman";
  };

  config = lib.mkIf cfg.enable {
    sops.templates.packages-registry-token = {
      content = config.sops.placeholder.packages_ghcr_token;
      mode = "0400";
      restartUnits = [ "packages-registry-login.service" ];
    };

    systemd.services.packages-registry-login = {
      description = "Authenticate rootful Podman to private GHCR packages";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # Stay inactive after success so refreshing credentials cannot stop
        # running services that require this login helper.
        ExecStart = pkgs.writeShellScript "packages-registry-login" ''
          exec ${pkgs.podman}/bin/podman login ghcr.io \
            --username rodrgds \
            --password-stdin < ${config.sops.templates.packages-registry-token.path}
        '';
      };
    };

    # Enable Podman
    virtualisation.podman = {
      enable = true;

      # Create a docker-compatible alias
      dockerCompat = true;

      # Required for containers under podman
      defaultNetwork.settings.dns_enabled = true;
    };

    # Use podman for oci-containers backend
    virtualisation.oci-containers.backend = "podman";

    # Install podman-compose for ad-hoc use
    environment.systemPackages = [ pkgs.podman-compose ];

    # Remove only dangling images and build cache. Tagged release images may not
    # have a persistent container (notably Unprompted's migration image).
    systemd.services.podman-image-prune = {
      description = "Prune dangling Podman images and build cache";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "podman-image-prune" ''
          set -euo pipefail
          exec ${pkgs.util-linux}/bin/flock --exclusive /run/podman-maintenance.lock \
            ${pkgs.podman}/bin/podman image prune --force --build-cache
        '';
      };
    };

    systemd.timers.podman-image-prune = {
      description = "Daily dangling Podman image cleanup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Storage for containers
    # Persistent data goes under /var/lib/<service>
    # This is managed by individual service modules
  };
}
