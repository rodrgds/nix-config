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
    enable = lib.mkEnableOption "Podman container runtime";
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

    # Storage for containers
    # Persistent data goes under /var/lib/<service>
    # This is managed by individual service modules
  };
}
