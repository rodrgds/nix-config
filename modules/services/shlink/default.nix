# Shlink URL shortener with multi-domain support and visit tracking
# https://shlink.io
#
# FIRST-TIME SETUP:
#   After first start, generate an API key for the web client:
#     sudo podman exec -it shlink shlink api-key:generate
#   Then add it to your sops secrets as `shlink_api_key`.
#
#   To register additional short domains after boot:
#     sudo podman exec -it shlink shlink domain:add short.example.com
#
# REQUIRED SOPS SECRETS:
#   shlink_db_password, shlink_db_user, shlink_db_name
#   shlink_geolite_license_key  (only if geoLiteEnabled = true)
#
# HOW TO USE:
#   Shorten a URL:
#     sudo podman exec -it shlink shlink short-url:create https://example.com --domain ref.rgo.pt --custom-slug test
#   View stats for a short URL:
#     sudo podman exec -it shlink shlink short-url:visits ref.rgo.pt/test
#   Access the web client UI at https://shlink-admin.rgo.pt
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.shlink;

  shlinkPort = 8087;
  webClientPort = 8088;
  postgresPort = 5437;
  redisPort = 6381;

  # Shlink resolves its own domain from DEFAULT_DOMAIN, but extra short-domains
  # must be added via CLI after first start (stored in DB). We expose the list
  # here purely for documentation / Caddy wiring purposes.
  allDomains = [ cfg.domain ] ++ cfg.extraDomains;

  caddyDomainPorts =
    builtins.listToAttrs (
      map (domain: {
        name = domain;
        value = shlinkPort;
      }) allDomains
    )
    // lib.optionalAttrs cfg.enableWebClient { "${cfg.webClientDomain}" = webClientPort; };
in
{
  options.vps.shlink = {
    enable = lib.mkEnableOption "Shlink URL shortener";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "url.rgo.pt";
      description = "Primary short-link domain (DEFAULT_DOMAIN in Shlink).";
    };

    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional short-link domains. Register each one after first boot with:
          sudo podman exec -it shlink shlink domain:add <domain>
        Caddy will be wired automatically for domains listed here.
      '';
    };

    enableWebClient = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Deploy the Shlink Web Client UI (shlink-web-client).";
    };

    webClientDomain = lib.mkOption {
      type = lib.types.str;
      default = "shlink-admin.rgo.pt";
      description = "Domain served by the Shlink Web Client container.";
    };

    geoLiteEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable GeoLite2 city database for visit geolocation tracking.
        Requires a free MaxMind licence key stored in sops as `shlink_geolite_license_key`.
      '';
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Lisbon";
      description = "Timezone for Shlink (affects visit stats grouping).";
    };

    shortenNotFoundAs404 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Return 404 for unknown short codes instead of redirecting to a base URL.";
    };
  };

  config = lib.mkIf cfg.enable {

    # -------------------------------------------------------------------------
    # Persistent directories
    # -------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d /var/lib/shlink                 0750 root root  -"
      "d /var/lib/shlink/postgres        0700 70   70    -" # postgres uid
      "d /var/lib/shlink/data            0750 1001 1001  -" # shlink uid inside container
      "d /var/backup/shlink              0750 root root  -"
    ];

    # -------------------------------------------------------------------------
    # PostgreSQL
    # -------------------------------------------------------------------------
    virtualisation.oci-containers.containers.shlink-postgres = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_USER_FILE = "/run/secrets/db_user";
        POSTGRES_DB_FILE = "/run/secrets/db_name";
        POSTGRES_PASSWORD_FILE = "/run/secrets/db_password";
      };

      volumes = [
        "/var/lib/shlink/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString postgresPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.shlink-db-password.path},target=/run/secrets/db_password,ro"
        "--mount=type=bind,source=${config.sops.templates.shlink-db-user.path},target=/run/secrets/db_user,ro"
        "--mount=type=bind,source=${config.sops.templates.shlink-db-name.path},target=/run/secrets/db_name,ro"
        "--health-cmd=pg_isready -U shlink -d shlink"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # -------------------------------------------------------------------------
    # Redis  (visit buffering, cache, async task queue)
    # -------------------------------------------------------------------------
    virtualisation.oci-containers.containers.shlink-redis = {
      image = "docker.io/redis:7-alpine";

      cmd = [
        "redis-server"
        "--save"
        "60"
        "1"
        "--loglevel"
        "warning"
      ];

      ports = [
        "127.0.0.1:${toString redisPort}:6379"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=redis-cli ping"
        "--health-interval=5s"
        "--health-timeout=5s"
        "--health-retries=10"
      ];
    };

    # -------------------------------------------------------------------------
    # Shlink application
    # -------------------------------------------------------------------------
    virtualisation.oci-containers.containers.shlink = {
      image = "shlinkio/shlink:stable";

      environment = {
        # Database
        DB_DRIVER = "postgres";
        DB_HOST = "shlink-postgres";
        DB_PORT = "5432";

        # Redis
        REDIS_SERVERS = "tcp://shlink-redis:6379";

        # Domain / URL
        DEFAULT_DOMAIN = cfg.domain;
        IS_HTTPS_ENABLED = "true";
        PORT = "8080";

        # Timezone & locale
        TIMEZONE = cfg.timezone;

        # Tracking
        TRACK_ORPHAN_VISITS = "true";
        DISABLE_TRACK_PARAM = ""; # set to e.g. "no_track" to honour opt-out param
        ANONYMIZE_REMOTE_ADDR = "false"; # set true for GDPR-strict deployments
        VISITS_WEBHOOKS_ENABLED = "false"; # set true + VISITS_WEBHOOKS_URLS if needed

        # GeoLite2 (populated from secrets below when enabled)
        GEOLITE_LICENSE_KEY = lib.mkIf cfg.geoLiteEnabled config.sops.placeholder.shlink_geolite_license_key;

        # Behaviour
        NOT_FOUND_REDIRECT_TO = lib.mkIf cfg.shortenNotFoundAs404 "";
        NOT_FOUND_STATUS_CODE = lib.mkIf cfg.shortenNotFoundAs404 "404";
        REDIRECT_STATUS_CODE = "302"; # change to 301 once stable
        REDIRECT_CACHE_LIFETIME = "30"; # seconds

        # Multi-segment slugs (allow slashes in short codes)
        MULTI_SEGMENT_SLUGS_ENABLED = "true";

        # Auto-resolve base url per domain (needed for multi-domain)
        DOMAIN_REDIRECT_FALLBACK_MODE = "none";
      };

      environmentFiles = [
        config.sops.templates.shlink-env.path
      ];

      volumes = [
        "/var/lib/shlink/data:/etc/shlink/data"
      ];

      ports = [
        "127.0.0.1:${toString shlinkPort}:8080"
      ];

      dependsOn = [
        "shlink-postgres"
        "shlink-redis"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -fs http://127.0.0.1:8080/rest/health"
        "--health-interval=10s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # -------------------------------------------------------------------------
    # Shlink Web Client  (optional admin UI)
    # -------------------------------------------------------------------------
    virtualisation.oci-containers.containers.shlink-web-client = lib.mkIf cfg.enableWebClient {
      image = "shlinkio/shlink-web-client:stable";

      # The web client is a static SPA — it connects from the *browser* to the
      # Shlink API, so SHLINK_SERVER_URL must be the public-facing URL.
      environment = {
        SHLINK_SERVER_URL = "https://${cfg.domain}";
        # API key is entered in the UI on first visit, or pre-configured here:
        # SHLINK_SERVER_API_KEY = "...";  # set via sops if you want auto-login
      };

      ports = [
        "127.0.0.1:${toString webClientPort}:8080"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=wget --no-verbose --tries=1 --spider http://127.0.0.1:8080"
        "--health-interval=10s"
        "--health-timeout=10s"
        "--health-retries=5"
      ];
    };

    # -------------------------------------------------------------------------
    # Secrets (sops-nix)
    # -------------------------------------------------------------------------
    sops.templates = {
      "shlink-db-password" = {
        content = config.sops.placeholder.shlink_db_password;
        mode = "0444";
      };
      "shlink-db-user" = {
        content = config.sops.placeholder.shlink_db_user;
        mode = "0444";
      };
      "shlink-db-name" = {
        content = config.sops.placeholder.shlink_db_name;
        mode = "0444";
      };

      # Main env file injected into the shlink container
      "shlink-env" = {
        content = ''
          DB_NAME=${config.sops.placeholder.shlink_db_name}
          DB_USER=${config.sops.placeholder.shlink_db_user}
          DB_PASSWORD=${config.sops.placeholder.shlink_db_password}
          ${lib.optionalString cfg.geoLiteEnabled "GEOLITE_LICENSE_KEY=${config.sops.placeholder.shlink_geolite_license_key}"}
        '';
        mode = "0444";
      };
    };

    # -------------------------------------------------------------------------
    # SQLite backup (shlink also stores generated GeoLite DB and some data here)
    # -------------------------------------------------------------------------
    systemd.services.shlink-backup = {
      description = "Backup Shlink PostgreSQL database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "shlink-backup" ''
          set -e
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/shlink"
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          ${pkgs.podman}/bin/podman exec shlink-postgres \
            pg_dumpall -U shlink \
            | ${pkgs.gzip}/bin/gzip > "$BACKUP_DIR/shlink_$TIMESTAMP.sql.gz"

          # Keep last 7 days
          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "shlink_*.sql.gz" -mtime +7 -delete

          echo "Shlink backup done: $BACKUP_DIR/shlink_$TIMESTAMP.sql.gz"
        '';
      };
    };

    systemd.timers.shlink-backup = {
      description = "Daily Shlink backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # -------------------------------------------------------------------------
    # Caddy
    # All short-link domains (primary + extra) proxy to the same Shlink port.
    # Shlink inspects the Host header internally to route per-domain slugs.
    # The web-client gets its own separate subdomain.
    # -------------------------------------------------------------------------
    vps.caddy.internalPorts = lib.mkMerge [
      (builtins.listToAttrs (
        map (d: {
          name = d;
          value = shlinkPort;
        }) allDomains
      ))
      (lib.optionalAttrs cfg.enableWebClient { "${cfg.webClientDomain}" = webClientPort; })
    ];
  };
}
