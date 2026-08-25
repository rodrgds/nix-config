# Postiz social media scheduler
# Multi-platform social media management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.postiz;

  postizPort = 4007;

  temporalDynamicConfig = pkgs.writeText "development-sql.yaml" ''
    limit.maxIDLength:
      - value: 255
        constraints: {}
    system.forceSearchAttributesCacheRefreshOnRead:
      - value: true # Dev setup only. Please don't turn this on in production.
        constraints: {}
  '';
in
{
  options.vps.postiz = {
    enable = lib.mkEnableOption "Enable Postiz";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "postiz.rgo.pt";
      description = "Domain for Postiz";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [
      "postiz_jwt_secret"
      "postiz_postgres_password"
      "postiz_db_name"
      "postiz_db_user"
      "postiz_discord_id"
      "postiz_discord_secret"
      "postiz_discord_token"
      "postiz_instagram_id"
      "postiz_instagram_secret"
      "postiz_linkedin_id"
      "postiz_linkedin_secret"
      "postiz_mastodon_id"
      "postiz_mastodon_secret"
      "postiz_openai_key"
      "postiz_threads_id"
      "postiz_threads_secret"
      "postiz_tiktok_id"
      "postiz_tiktok_secret"
      "postiz_x_api"
      "postiz_x_secret"
      "postiz_youtube_id"
      "postiz_youtube_secret"
    ] (_: { });

    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/postiz 0750 root root -"
      "d /var/lib/postiz/postgres 0750 999 999 -"
      "d /var/lib/postiz/redis 0750 1000 1000 -"
      "d /var/lib/postiz/config 0750 1000 1000 -"
      "d /var/lib/postiz/uploads 0750 1000 1000 -"
      "d /var/lib/postiz/temporal 0750 root root -"
      "d /var/lib/postiz/temporal/postgresql 0750 999 999 -"
      "d /var/lib/postiz/temporal/elasticsearch 0750 1000 1000 -"
    ];

    # PostgreSQL for Postiz
    virtualisation.oci-containers.containers.postiz-postgres = {
      image = "docker.io/postgres:17-alpine";

      environmentFiles = [
        config.sops.templates.postiz-postgres-env.path
      ];

      volumes = [
        "/var/lib/postiz/postgres:/var/lib/postgresql/data"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=pg_isready -U postiz-user -d postiz-db-local"
        "--health-interval=10s"
        "--health-timeout=3s"
        "--health-retries=3"
      ];
    };

    # Redis for Postiz
    virtualisation.oci-containers.containers.postiz-redis = {
      image = "docker.io/redis:7.2-alpine";

      volumes = [
        "/var/lib/postiz/redis:/data"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=redis-cli ping"
        "--health-interval=10s"
        "--health-timeout=3s"
        "--health-retries=3"
      ];
    };

    # Postiz main application
    virtualisation.oci-containers.containers.postiz = {
      image = "ghcr.io/gitroomhq/postiz-app:latest";

      environment = {
        MAIN_URL = "https://${cfg.domain}";
        FRONTEND_URL = "https://${cfg.domain}";
        NEXT_PUBLIC_BACKEND_URL = "https://${cfg.domain}/api";
        BACKEND_INTERNAL_URL = "http://localhost:3000";
        REDIS_URL = "redis://postiz-redis:6379";
        IS_GENERAL = "true";
        DISABLE_REGISTRATION = "false";
        RUN_CRON = "true";
        API_LIMIT = "1000";
        NX_ADD_PLUGINS = "false";
        TEMPORAL_ADDRESS = "postiz-temporal:7233";

        # Storage
        STORAGE_PROVIDER = "local";
        UPLOAD_DIRECTORY = "/uploads";
        NEXT_PUBLIC_UPLOAD_DIRECTORY = "/uploads";

        # Social Media API Keys
        X_API_KEY_FILE = "/run/secrets/x_api";
        X_API_SECRET_FILE = "/run/secrets/x_secret";
        LINKEDIN_CLIENT_ID_FILE = "/run/secrets/linkedin_id";
        LINKEDIN_CLIENT_SECRET_FILE = "/run/secrets/linkedin_secret";
        DISCORD_CLIENT_ID_FILE = "/run/secrets/discord_id";
        DISCORD_CLIENT_SECRET_FILE = "/run/secrets/discord_secret";
        DISCORD_BOT_TOKEN_ID_FILE = "/run/secrets/discord_token";
        INSTAGRAM_APP_ID_FILE = "/run/secrets/instagram_id";
        INSTAGRAM_APP_SECRET_FILE = "/run/secrets/instagram_secret";
        THREADS_APP_ID_FILE = "/run/secrets/threads_id";
        THREADS_APP_SECRET_FILE = "/run/secrets/threads_secret";
        TIKTOK_CLIENT_ID_FILE = "/run/secrets/tiktok_id";
        TIKTOK_CLIENT_SECRET_FILE = "/run/secrets/tiktok_secret";
        YOUTUBE_CLIENT_ID_FILE = "/run/secrets/youtube_id";
        YOUTUBE_CLIENT_SECRET_FILE = "/run/secrets/youtube_secret";
        MASTODON_CLIENT_ID_FILE = "/run/secrets/mastodon_id";
        MASTODON_CLIENT_SECRET_FILE = "/run/secrets/mastodon_secret";
        MASTODON_URL = "https://mastodon.social";
        OPENAI_API_KEY_FILE = "/run/secrets/openai_key";

        # Misc
        NEXT_PUBLIC_DISCORD_SUPPORT = "";
        NEXT_PUBLIC_POLOTNO = "";
        FEE_AMOUNT = "0.05";
        EXTENSION_ID = "icpokdlcikdmemjkeoojhocmhmehpaia";
      };

      environmentFiles = [
        config.sops.templates.postiz-env.path
      ];

      volumes = [
        "/var/lib/postiz/config:/config"
        "/var/lib/postiz/uploads:/uploads"
      ];

      ports = [
        "127.0.0.1:4201:4200"
        "127.0.0.1:${toString postizPort}:5000"
      ];

      dependsOn = [
        "postiz-postgres"
        "postiz-redis"
        "postiz-temporal"
      ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.postiz-jwt.path},target=/run/secrets/jwt_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-x-api.path},target=/run/secrets/x_api,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-x-secret.path},target=/run/secrets/x_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-linkedin-id.path},target=/run/secrets/linkedin_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-linkedin-secret.path},target=/run/secrets/linkedin_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-discord-id.path},target=/run/secrets/discord_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-discord-secret.path},target=/run/secrets/discord_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-discord-token.path},target=/run/secrets/discord_token,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-instagram-id.path},target=/run/secrets/instagram_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-instagram-secret.path},target=/run/secrets/instagram_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-threads-id.path},target=/run/secrets/threads_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-threads-secret.path},target=/run/secrets/threads_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-tiktok-id.path},target=/run/secrets/tiktok_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-tiktok-secret.path},target=/run/secrets/tiktok_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-youtube-id.path},target=/run/secrets/youtube_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-youtube-secret.path},target=/run/secrets/youtube_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-mastodon-id.path},target=/run/secrets/mastodon_id,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-mastodon-secret.path},target=/run/secrets/mastodon_secret,ro"
        "--mount=type=bind,source=${config.sops.templates.postiz-openai.path},target=/run/secrets/openai_key,ro"
      ];
    };

    # Temporal infrastructure for Postiz v2.12.0+
    # Temporal Elasticsearch
    virtualisation.oci-containers.containers.postiz-temporal-elasticsearch = {
      image = "docker.io/elasticsearch:7.17.27";

      environment = {
        "cluster.routing.allocation.disk.threshold_enabled" = "true";
        "cluster.routing.allocation.disk.watermark.low" = "512mb";
        "cluster.routing.allocation.disk.watermark.high" = "256mb";
        "cluster.routing.allocation.disk.watermark.flood_stage" = "128mb";
        "discovery.type" = "single-node";
        "ES_JAVA_OPTS" = "-Xms256m -Xmx256m";
        "xpack.security.enabled" = "false";
      };

      volumes = [
        "/var/lib/postiz/temporal/elasticsearch:/var/lib/elasticsearch/data"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Temporal PostgreSQL
    virtualisation.oci-containers.containers.postiz-temporal-postgresql = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_PASSWORD = "temporal";
        POSTGRES_USER = "temporal";
      };

      volumes = [
        "/var/lib/postiz/temporal/postgresql:/var/lib/postgresql/data"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Temporal server
    virtualisation.oci-containers.containers.postiz-temporal = {
      image = "docker.io/temporalio/auto-setup:1.28.1";

      environment = {
        DB = "postgres12";
        DB_PORT = "5432";
        POSTGRES_USER = "temporal";
        POSTGRES_PWD = "temporal";
        POSTGRES_SEEDS = "postiz-temporal-postgresql";
        ENABLE_ES = "true";
        ES_SEEDS = "postiz-temporal-elasticsearch";
        ES_VERSION = "v7";
        TEMPORAL_NAMESPACE = "default";
        DYNAMIC_CONFIG_FILE_PATH = "config/dynamicconfig/development-sql.yaml";
      };

      dependsOn = [
        "postiz-temporal-postgresql"
        "postiz-temporal-elasticsearch"
      ];

      extraOptions = [
        "--network=podman"
        "--expose=7233"
        "--mount=type=bind,source=${temporalDynamicConfig},target=/etc/temporal/config/dynamicconfig/development-sql.yaml,ro"
      ];
    };

    # Temporal admin tools
    virtualisation.oci-containers.containers.postiz-temporal-admin-tools = {
      image = "docker.io/temporalio/admin-tools:1.28.1-tctl-1.18.4-cli-1.4.1";

      environment = {
        TEMPORAL_ADDRESS = "postiz-temporal:7233";
        TEMPORAL_CLI_ADDRESS = "postiz-temporal:7233";
      };

      dependsOn = [
        "postiz-temporal"
      ];

      extraOptions = [
        "--network=podman"
        "--interactive"
        "--tty"
      ];
    };

    # Temporal UI
    virtualisation.oci-containers.containers.postiz-temporal-ui = {
      image = "docker.io/temporalio/ui:2.34.0";

      environment = {
        TEMPORAL_ADDRESS = "postiz-temporal:7233";
        TEMPORAL_CORS_ORIGINS = "http://127.0.0.1:3000";
      };

      ports = [
        "127.0.0.1:8080:8080"
      ];

      dependsOn = [
        "postiz-temporal"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Secrets
    sops.templates = {
      "postiz-postgres-env" = {
        content = ''
          POSTGRES_USER=${config.sops.placeholder.postiz_db_user}
          POSTGRES_PASSWORD=${config.sops.placeholder.postiz_postgres_password}
          POSTGRES_DB=${config.sops.placeholder.postiz_db_name}
        '';
      };
      "postiz-env" = {
        content = ''
          POSTGRES_USER=${config.sops.placeholder.postiz_db_user}
          POSTGRES_PASSWORD=${config.sops.placeholder.postiz_postgres_password}
          POSTGRES_DB=${config.sops.placeholder.postiz_db_name}
          DATABASE_URL=postgresql://${config.sops.placeholder.postiz_db_user}:${config.sops.placeholder.postiz_postgres_password}@postiz-postgres:5432/${config.sops.placeholder.postiz_db_name}
          JWT_SECRET=${config.sops.placeholder.postiz_jwt_secret}
        '';
      };
      "postiz-jwt" = {
        content = config.sops.placeholder.postiz_jwt_secret;
      };
      "postiz-x-api" = {
        content = config.sops.placeholder.postiz_x_api;
      };
      "postiz-x-secret" = {
        content = config.sops.placeholder.postiz_x_secret;
      };
      "postiz-linkedin-id" = {
        content = config.sops.placeholder.postiz_linkedin_id;
      };
      "postiz-linkedin-secret" = {
        content = config.sops.placeholder.postiz_linkedin_secret;
      };
      "postiz-discord-id" = {
        content = config.sops.placeholder.postiz_discord_id;
      };
      "postiz-discord-secret" = {
        content = config.sops.placeholder.postiz_discord_secret;
      };
      "postiz-discord-token" = {
        content = config.sops.placeholder.postiz_discord_token;
      };
      "postiz-instagram-id" = {
        content = config.sops.placeholder.postiz_instagram_id;
      };
      "postiz-instagram-secret" = {
        content = config.sops.placeholder.postiz_instagram_secret;
      };
      "postiz-threads-id" = {
        content = config.sops.placeholder.postiz_threads_id;
      };
      "postiz-threads-secret" = {
        content = config.sops.placeholder.postiz_threads_secret;
      };
      "postiz-tiktok-id" = {
        content = config.sops.placeholder.postiz_tiktok_id;
      };
      "postiz-tiktok-secret" = {
        content = config.sops.placeholder.postiz_tiktok_secret;
      };
      "postiz-youtube-id" = {
        content = config.sops.placeholder.postiz_youtube_id;
      };
      "postiz-youtube-secret" = {
        content = config.sops.placeholder.postiz_youtube_secret;
      };
      "postiz-mastodon-id" = {
        content = config.sops.placeholder.postiz_mastodon_id;
      };
      "postiz-mastodon-secret" = {
        content = config.sops.placeholder.postiz_mastodon_secret;
      };
      "postiz-openai" = {
        content = config.sops.placeholder.postiz_openai_key;
      };
    };

    # Caddy
    vps.caddy.internalPorts.postiz = postizPort;
    vps.caddy.internalPorts.postiz-temporal-ui = 8080;
  };
}
