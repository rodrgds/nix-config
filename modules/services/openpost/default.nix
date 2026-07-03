# OpenPost - Multi-platform social media posting
# https://github.com/rodrgds/openpost
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.openpost;
  isCloud = cfg.edition == "cloud";

  # Host port (external) - must be unique per service
  openpostHostPort = 8090;
  # Container port (internal) - OpenPost listens on 8080 inside container
  openpostContainerPort = 8080;
  openpostPostgresUser = "openpost";
  openpostPostgresDatabase = "openpost";

  openpostFileSecrets = [
    {
      name = "jwt-secret";
      env = "OPENPOST_JWT_SECRET_FILE";
      target = "/run/secrets/openpost_jwt_secret";
      value = config.sops.placeholder.openpost_jwt_secret;
    }
    {
      name = "encryption-key";
      env = "OPENPOST_ENCRYPTION_KEY_FILE";
      target = "/run/secrets/openpost_encryption_key";
      value = config.sops.placeholder.openpost_encryption_key;
    }
    {
      name = "x-client-id";
      env = "X_CLIENT_ID_FILE";
      target = "/run/secrets/openpost_twitter_client_id";
      value = config.sops.placeholder.openpost_twitter_client_id;
    }
    {
      name = "x-client-secret";
      env = "X_CLIENT_SECRET_FILE";
      target = "/run/secrets/openpost_twitter_client_secret";
      value = config.sops.placeholder.openpost_twitter_client_secret;
    }
    {
      name = "linkedin-client-id";
      env = "LINKEDIN_CLIENT_ID_FILE";
      target = "/run/secrets/openpost_linkedin_client_id";
      value = config.sops.placeholder.openpost_linkedin_client_id;
    }
    {
      name = "linkedin-client-secret";
      env = "LINKEDIN_CLIENT_SECRET_FILE";
      target = "/run/secrets/openpost_linkedin_client_secret";
      value = config.sops.placeholder.openpost_linkedin_client_secret;
    }
    {
      name = "threads-client-id";
      env = "THREADS_CLIENT_ID_FILE";
      target = "/run/secrets/openpost_threads_client_id";
      value = config.sops.placeholder.openpost_threads_client_id;
    }
    {
      name = "threads-client-secret";
      env = "THREADS_CLIENT_SECRET_FILE";
      target = "/run/secrets/openpost_threads_client_secret";
      value = config.sops.placeholder.openpost_threads_client_secret;
    }
    {
      name = "mastodon-servers";
      env = "MASTODON_SERVERS_FILE";
      target = "/run/secrets/openpost_mastodon_servers";
      value = config.sops.placeholder.openpost_mastodon_servers;
    }
  ];

  openpostFileSecretEnvironment = lib.listToAttrs (
    map (secret: lib.nameValuePair secret.env secret.target) openpostFileSecrets
  );

  openpostFileSecretTemplates = lib.listToAttrs (
    map (
      secret:
      lib.nameValuePair "openpost-${secret.name}" {
        content = secret.value;
        mode = "0444";
      }
    ) openpostFileSecrets
  );

  openpostFileSecretMounts = map (
    secret:
    let
      templateName = "openpost-${secret.name}";
    in
    "--mount=type=bind,source=${config.sops.templates.${templateName}.path},target=${secret.target},ro"
  ) openpostFileSecrets;

in
{
  options.vps.openpost = {
    enable = lib.mkEnableOption "Enable OpenPost";

    edition = lib.mkOption {
      type = lib.types.enum [
        "selfhost"
        "cloud"
      ];
      default = "selfhost";
      description = ''
        OpenPost edition. `selfhost` keeps SQLite and local media defaults.
        `cloud` wires the container for Postgres and S3-compatible storage.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "app.openpost.social";
      description = "Domain for OpenPost";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Lisbon";
      description = "Timezone for OpenPost";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/rodrgds/openpost:latest";
      description = ''
        OpenPost container image. Pin this to a release tag or digest for
        reproducible production deploys.
      '';
    };

    pullPolicy = lib.mkOption {
      type = lib.types.enum [
        "always"
        "missing"
        "never"
      ];
      default = "always";
      description = ''
        Podman image pull policy for OpenPost. The default keeps the hosted
        service from reusing a stale local `latest` image after a Nix switch.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra OpenPost environment variables. Use this for non-secret cloud
        settings, temporary overrides, or *_FILE pointers to mounted secrets.
      '';
    };

    extraEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Extra env files passed to the OpenPost container. In cloud mode this
        should provide OPENPOST_DATABASE_URL, S3 credentials, Polar product
        secrets, or *_FILE pointers unless they are set via extraEnvironment.
      '';
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra Podman options for OpenPost. Use this to bind-mount additional
        secret files referenced by *_FILE environment variables.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    # Note: Container runs as user 'openpost' (UID 1000)
    systemd.tmpfiles.rules = [
      "d /var/lib/openpost 0755 root root -"
    ]
    ++ lib.optionals isCloud [
      "d /var/lib/openpost/postgres 0700 70 70 -"
      "d /var/backup/openpost 0750 root root -"
    ]
    ++ lib.optionals (!isCloud) [
      "d /var/lib/openpost/data 0755 1000 1000 -"
      "d /var/lib/openpost/data/db 0755 1000 1000 -"
      "d /var/lib/openpost/data/media 0755 1000 1000 -"
    ];

    # OpenPost application
    virtualisation.oci-containers.containers.openpost = {
      image = cfg.image;

      environment = {
        OPENPOST_PORT = toString openpostContainerPort;
        OPENPOST_EDITION = cfg.edition;
        OPENPOST_APP_URL = "https://${cfg.domain}";
        OPENPOST_PUBLIC_URL = "https://${cfg.domain}";
        OPENPOST_EXTRA_CORS_ORIGINS = "https://${cfg.domain}";
        OPENPOST_DISABLE_REGISTRATIONS = "false";
        LINKEDIN_DISABLE_THREAD_REPLIES = "true";
        X_REDIRECT_URI = "https://${cfg.domain}/api/v1/accounts/x/callback";
        LINKEDIN_REDIRECT_URI = "https://${cfg.domain}/api/v1/accounts/linkedin/callback";
        THREADS_REDIRECT_URI = "https://${cfg.domain}/api/v1/accounts/threads/callback";
        MASTODON_REDIRECT_URI = "https://${cfg.domain}/api/v1/accounts/mastodon/callback";
        TZ = cfg.timezone;
      }
      // openpostFileSecretEnvironment
      // (
        if isCloud then
          {
            OPENPOST_DATABASE_DRIVER = "postgres";
            OPENPOST_STORAGE_DRIVER = "s3";
          }
        else
          {
            OPENPOST_DATABASE_DRIVER = "sqlite";
            OPENPOST_DATABASE_PATH = "/data/db/openpost.db";
            OPENPOST_STORAGE_DRIVER = "local";
            OPENPOST_MEDIA_PATH = "/data/media";
            OPENPOST_MEDIA_URL = "https://${cfg.domain}/media";
          }
      )
      // cfg.extraEnvironment;

      environmentFiles =
        cfg.extraEnvironmentFiles
        ++ lib.optionals isCloud [
          config.sops.templates.openpost-cloud-env.path
        ];

      volumes = lib.optionals (!isCloud) [
        "/var/lib/openpost/data:/data"
      ];

      dependsOn = lib.optionals isCloud [ "openpost-postgres" ];

      ports = [
        "127.0.0.1:${toString openpostHostPort}:${toString openpostContainerPort}"
      ];

      extraOptions = [
        "--network=podman"
        "--pull=${cfg.pullPolicy}"
        "--health-cmd=wget --spider http://localhost:${toString openpostContainerPort}/api/v1/ready"
        "--health-interval=30s"
        "--health-timeout=3s"
        "--health-retries=3"
      ]
      ++ openpostFileSecretMounts
      ++ cfg.extraOptions;
    };

    virtualisation.oci-containers.containers.openpost-postgres = lib.mkIf isCloud {
      image = "docker.io/postgres:17-alpine";

      environmentFiles = [
        config.sops.templates.openpost-postgres-env.path
      ];

      volumes = [
        "/var/lib/openpost/postgres:/var/lib/postgresql/data"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=pg_isready -U ${openpostPostgresUser} -d ${openpostPostgresDatabase}"
        "--health-interval=10s"
        "--health-timeout=5s"
        "--health-retries=12"
      ];
    };

    sops.templates =
      openpostFileSecretTemplates
      // lib.optionalAttrs isCloud {
        "openpost-postgres-env" = {
          content = ''
            POSTGRES_USER=${openpostPostgresUser}
            POSTGRES_DB=${openpostPostgresDatabase}
            POSTGRES_PASSWORD=${config.sops.placeholder.openpost_postgres_password}
          '';
          mode = "0444";
        };
        "openpost-cloud-env" = {
          content = ''
            OPENPOST_DATABASE_URL=postgres://${openpostPostgresUser}:${config.sops.placeholder.openpost_postgres_password}@openpost-postgres:5432/${openpostPostgresDatabase}?sslmode=disable
            OPENPOST_S3_ENDPOINT=${config.sops.placeholder.openpost_s3_endpoint}
            OPENPOST_S3_REGION=${config.sops.placeholder.openpost_s3_region}
            OPENPOST_S3_BUCKET=${config.sops.placeholder.openpost_s3_bucket}
            OPENPOST_S3_ACCESS_KEY_ID=${config.sops.placeholder.openpost_s3_access_key_id}
            OPENPOST_S3_SECRET_ACCESS_KEY=${config.sops.placeholder.openpost_s3_secret_access_key}
            OPENPOST_S3_PUBLIC_BASE_URL=${config.sops.placeholder.openpost_s3_public_base_url}
            OPENPOST_POLAR_ACCESS_TOKEN=${config.sops.placeholder.openpost_polar_access_token}
            OPENPOST_POLAR_WEBHOOK_SECRET=${config.sops.placeholder.openpost_polar_webhook_secret}
            OPENPOST_POLAR_CHECKOUT_SUCCESS_URL=https://${cfg.domain}/settings?tab=billing&checkout_id={CHECKOUT_ID}
            OPENPOST_POLAR_RETURN_URL=https://${cfg.domain}/settings?tab=billing
            OPENPOST_POLAR_STARTER_PRODUCT_ID=${config.sops.placeholder.openpost_polar_starter_product_id}
            OPENPOST_POLAR_CREATOR_PRODUCT_ID=${config.sops.placeholder.openpost_polar_creator_product_id}
            OPENPOST_POLAR_PRO_PRODUCT_ID=${config.sops.placeholder.openpost_polar_pro_product_id}
            OPENPOST_POLAR_TEAM_PRODUCT_ID=${config.sops.placeholder.openpost_polar_team_product_id}
            OPENPOST_POLAR_AGENCY_PRODUCT_ID=${config.sops.placeholder.openpost_polar_agency_product_id}
          '';
          mode = "0444";
        };
      };

    systemd.services.openpost-postgres-backup = lib.mkIf isCloud {
      description = "Backup OpenPost Postgres database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "openpost-postgres-backup" ''
          set -euo pipefail
          timestamp=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          backup_dir=/var/backup/openpost
          ${pkgs.coreutils}/bin/mkdir -p "$backup_dir"

          ${pkgs.podman}/bin/podman exec openpost-postgres pg_dump \
            -U ${openpostPostgresUser} \
            -d ${openpostPostgresDatabase} | ${pkgs.gzip}/bin/gzip > "$backup_dir/openpost_$timestamp.sql.gz"

          ${pkgs.findutils}/bin/find "$backup_dir" -name 'openpost_*.sql.gz' -mtime +14 -delete
        '';
      };
    };

    systemd.timers.openpost-postgres-backup = lib.mkIf isCloud {
      description = "Daily OpenPost Postgres backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    vps.caddy.internalPorts.openpost = openpostHostPort;
  };
}
