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

  cloudRequiredEnvNames = [
    "OPENPOST_DATABASE_URL"
    "OPENPOST_S3_REGION"
    "OPENPOST_S3_BUCKET"
    "OPENPOST_S3_ACCESS_KEY_ID"
    "OPENPOST_S3_SECRET_ACCESS_KEY"
    "OPENPOST_S3_PUBLIC_BASE_URL"
    "OPENPOST_POLAR_ACCESS_TOKEN"
    "OPENPOST_POLAR_WEBHOOK_SECRET"
    "OPENPOST_POLAR_STARTER_PRODUCT_ID"
    "OPENPOST_POLAR_CREATOR_PRODUCT_ID"
    "OPENPOST_POLAR_PRO_PRODUCT_ID"
  ];

  hasCloudInlineEnv = builtins.all (
    name: builtins.hasAttr name cfg.extraEnvironment
  ) cloudRequiredEnvNames;
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

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra OpenPost environment variables. Use this for non-secret cloud
        settings or temporary overrides.
      '';
    };

    extraEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Extra env files passed to the OpenPost container. In cloud mode this
        should provide OPENPOST_DATABASE_URL, S3 credentials, and Polar product
        secrets unless they are set via extraEnvironment.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    # Note: Container runs as user 'openpost' (UID 1000)
    systemd.tmpfiles.rules = [
      "d /var/lib/openpost 0755 root root -"
    ]
    ++ lib.optionals (!isCloud) [
      "d /var/lib/openpost/data 0755 1000 1000 -"
      "d /var/lib/openpost/data/db 0755 1000 1000 -"
      "d /var/lib/openpost/data/media 0755 1000 1000 -"
    ];

    # OpenPost application
    virtualisation.oci-containers.containers.openpost = {
      image = "ghcr.io/rodrgds/openpost:latest";

      environment = {
        OPENPOST_PORT = toString openpostContainerPort;
        OPENPOST_EDITION = cfg.edition;
        OPENPOST_APP_URL = "https://${cfg.domain}";
        OPENPOST_PUBLIC_URL = "https://${cfg.domain}";
        OPENPOST_EXTRA_CORS_ORIGINS = "https://${cfg.domain}";
        OPENPOST_DISABLE_REGISTRATIONS = "false";
        LINKEDIN_DISABLE_THREAD_REPLIES = "true";
        TZ = cfg.timezone;
      }
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

      environmentFiles = [
        config.sops.templates.openpost-env.path
      ]
      ++ cfg.extraEnvironmentFiles;

      volumes = lib.optionals (!isCloud) [
        "/var/lib/openpost/data:/data"
      ];

      ports = [
        "127.0.0.1:${toString openpostHostPort}:${toString openpostContainerPort}"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=wget --spider http://localhost:${toString openpostContainerPort}/api/v1/ready"
        "--health-interval=30s"
        "--health-timeout=3s"
        "--health-retries=3"
      ];
    };

    sops.templates = {
      "openpost-env" = {
        content = ''
          OPENPOST_JWT_SECRET=${config.sops.placeholder.openpost_jwt_secret}
          OPENPOST_ENCRYPTION_KEY=${config.sops.placeholder.openpost_encryption_key}
          X_CLIENT_ID=${config.sops.placeholder.openpost_twitter_client_id}
          X_CLIENT_SECRET=${config.sops.placeholder.openpost_twitter_client_secret}
          X_REDIRECT_URI=https://${cfg.domain}/api/v1/accounts/x/callback
          LINKEDIN_CLIENT_ID=${config.sops.placeholder.openpost_linkedin_client_id}
          LINKEDIN_CLIENT_SECRET=${config.sops.placeholder.openpost_linkedin_client_secret}
          LINKEDIN_REDIRECT_URI=https://${cfg.domain}/api/v1/accounts/linkedin/callback
          THREADS_CLIENT_ID=${config.sops.placeholder.openpost_threads_client_id}
          THREADS_CLIENT_SECRET=${config.sops.placeholder.openpost_threads_client_secret}
          THREADS_REDIRECT_URI=https://${cfg.domain}/api/v1/accounts/threads/callback
          MASTODON_REDIRECT_URI=https://${cfg.domain}/api/v1/accounts/mastodon/callback
          MASTODON_SERVERS=${config.sops.placeholder.openpost_mastodon_servers}
        '';
        mode = "0444";
      };
    };

    vps.caddy.internalPorts.openpost = openpostHostPort;

    assertions = [
      {
        assertion = !isCloud || cfg.extraEnvironmentFiles != [ ] || hasCloudInlineEnv;
        message = ''
          vps.openpost.edition = "cloud" requires either vps.openpost.extraEnvironmentFiles
          or these keys in vps.openpost.extraEnvironment: ${lib.concatStringsSep ", " cloudRequiredEnvNames}.
        '';
      }
    ];
  };
}
