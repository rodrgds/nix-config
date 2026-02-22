# Directus Headless CMS (SQLite)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.directus;
  directusPort = 8055;
in
{
  options.vps.directus = {
    enable = lib.mkEnableOption "Directus Headless CMS";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "directus.rgo.pt";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/directus 0750 root root -"
      "d /var/lib/directus/database 0750 1000 1000 -"
      "d /var/lib/directus/uploads 0750 1000 1000 -"
      "d /var/lib/directus/extensions 0750 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.directus = {
      image = "directus/directus:latest";

      environment = {
        DB_CLIENT = "sqlite3";
        DB_FILENAME = "/directus/database/data.db";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "true";
      };

      environmentFiles = [
        config.sops.templates.directus-env.path
      ];

      volumes = [
        "/var/lib/directus/database:/directus/database"
        "/var/lib/directus/uploads:/directus/uploads"
        "/var/lib/directus/extensions:/directus/extensions"
      ];

      ports = [
        "127.0.0.1:${toString directusPort}:8055"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    sops.templates."directus-env" = {
      content = ''
        KEY=${config.sops.placeholder.directus_key}
        SECRET=${config.sops.placeholder.directus_secret}
        ADMIN_EMAIL=${config.sops.placeholder.directus_admin_email}
        ADMIN_PASSWORD=${config.sops.placeholder.directus_admin_password}
      '';
      mode = "0444";
    };

    vps.caddy.internalPorts.directus = directusPort;
  };
}
