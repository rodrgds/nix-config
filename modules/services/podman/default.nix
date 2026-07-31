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

    # Keep superseded image generations and build cache from filling the VPS.
    # Images referenced by any container are never removed by image prune.
    systemd.services.podman-image-prune = {
      description = "Prune unused Podman images and build cache";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "podman-image-prune" ''
          set -euo pipefail
          exec ${pkgs.util-linux}/bin/flock --exclusive /run/podman-maintenance.lock \
            ${pkgs.podman}/bin/podman image prune --all --force --build-cache
        '';
      };
    };

    systemd.timers.podman-image-prune = {
      description = "Daily unused Podman image cleanup";
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
