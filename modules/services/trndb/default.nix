# TRNDb Directus Headless CMS (SQLite)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.trndb;
  trndbPort = 8056;
in
{
  options.vps.trndb = {
    enable = lib.mkEnableOption "TRNDb Directus Headless CMS";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "trndb.rgo.pt";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/trndb 0750 root root -"
      "d /var/lib/trndb/database 0750 1000 1000 -"
      "d /var/lib/trndb/uploads 0750 1000 1000 -"
      "d /var/lib/trndb/extensions 0750 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.trndb = {
      image = "directus/directus:latest";

      environment = {
        DB_CLIENT = "sqlite3";
        DB_FILENAME = "/directus/database/data.db";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "true";
      };

      environmentFiles = [
        config.sops.templates.trndb-env.path
      ];

      volumes = [
        "/var/lib/trndb/database:/directus/database"
        "/var/lib/trndb/uploads:/directus/uploads"
        "/var/lib/trndb/extensions:/directus/extensions"
      ];

      ports = [
        "127.0.0.1:${toString trndbPort}:8055"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    sops.templates."trndb-env" = {
      content = ''
        KEY=${config.sops.placeholder.trndb_key}
        SECRET=${config.sops.placeholder.trndb_secret}
        ADMIN_EMAIL=${config.sops.placeholder.trndb_admin_email}
        ADMIN_PASSWORD=${config.sops.placeholder.trndb_admin_password}
      '';
      mode = "0444";
    };

    vps.caddy.internalPorts.trndb = trndbPort;
  };
}
