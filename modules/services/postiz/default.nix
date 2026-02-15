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
in
{
  options.vps.postiz = {
    enable = lib.mkEnableOption "Postiz social media scheduler";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "postiz.rgo.pt";
      description = "Domain for Postiz";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/postiz 0750 root root -"
      "d /var/lib/postiz/postgres 0750 999 999 -"
      "d /var/lib/postiz/redis 0750 1000 1000 -"
      "d /var/lib/postiz/config 0750 1000 1000 -"
      "d /var/lib/postiz/uploads 0750 1000 1000 -"
      "d /var/lib/postiz/temporal 0750 1000 1000 -"
      "d /var/lib/postiz/elasticsearch 0750 1000 1000 -"
    ];

    # PostgreSQL for Postiz
    virtualisation.oci-containers.containers.postiz-postgres = {
      image = "docker.io/postgres:17-alpine";

      environment = {
        POSTGRES_USER = config.sops.placeholder.postiz_db_user;
        POSTGRES_PASSWORD = config.sops.placeholder.postiz_postgres_password;
        POSTGRES_DB = config.sops.placeholder.postiz_db_name;
      };

      volumes = [
        "/var/lib/postiz/postgres:/var/lib/postgresql/data"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=pg_isready -U ${config.sops.placeholder.postiz_db_user} -d ${config.sops.placeholder.postiz_db_name}"
        "--health-interval=10s"
        "--health-timeout=3s"
        "--health-retries=3"
      ];
    };

    # Redis for Postiz
    virtualisation.oci-containers.containers.postiz-redis = {
      image = "docker.io/redis:7.2";

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
        JWT_SECRET_FILE = "/run/secrets/jwt_secret";
        DATABASE_URL = "postgresql://${config.sops.placeholder.postiz_db_user}:${config.sops.placeholder.postiz_postgres_password}@postiz-postgres:5432/${config.sops.placeholder.postiz_db_name}";
        REDIS_URL = "redis://postiz-redis:6379";
        TEMPORAL_ADDRESS = "postiz-temporal:7233";
        IS_GENERAL = "true";
        DISABLE_REGISTRATION = "false";
        RUN_CRON = "true";
        API_LIMIT = "1000";
        NX_ADD_PLUGINS = "false";

        # Storage
        STORAGE_PROVIDER = "local";
        UPLOAD_DIRECTORY = "/uploads";
        NEXT_PUBLIC_UPLOAD_DIRECTORY = "/uploads";

        # Social Media API Keys (files)
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

      volumes = [
        "/var/lib/postiz/config:/config"
        "/var/lib/postiz/uploads:/uploads"
      ];

      ports = [
        "127.0.0.1:${toString postizPort}:5000"
      ];

      dependsOn = [
        "postiz-postgres"
        "postiz-redis"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Secrets
    sops.templates = {
      "postiz-jwt" = {
        content = config.sops.placeholder.postiz_jwt_secret;
      };
      "postiz-postgres" = {
        content = config.sops.placeholder.postiz_postgres_password;
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

    # Load secrets
    systemd.services.podman-postiz-postgres.serviceConfig = {
      LoadCredential = [ "postgres_password:${config.sops.templates.postiz-postgres.path}" ];
    };

    systemd.services.podman-postiz.serviceConfig = {
      LoadCredential = [
        "jwt_secret:${config.sops.templates.postiz-jwt.path}"
        "x_api:${config.sops.templates.postiz-x-api.path}"
        "x_secret:${config.sops.templates.postiz-x-secret.path}"
        "linkedin_id:${config.sops.templates.postiz-linkedin-id.path}"
        "linkedin_secret:${config.sops.templates.postiz-linkedin-secret.path}"
        "discord_id:${config.sops.templates.postiz-discord-id.path}"
        "discord_secret:${config.sops.templates.postiz-discord-secret.path}"
        "discord_token:${config.sops.templates.postiz-discord-token.path}"
        "instagram_id:${config.sops.templates.postiz-instagram-id.path}"
        "instagram_secret:${config.sops.templates.postiz-instagram-secret.path}"
        "threads_id:${config.sops.templates.postiz-threads-id.path}"
        "threads_secret:${config.sops.templates.postiz-threads-secret.path}"
        "tiktok_id:${config.sops.templates.postiz-tiktok-id.path}"
        "tiktok_secret:${config.sops.templates.postiz-tiktok-secret.path}"
        "youtube_id:${config.sops.templates.postiz-youtube-id.path}"
        "youtube_secret:${config.sops.templates.postiz-youtube-secret.path}"
        "mastodon_id:${config.sops.templates.postiz-mastodon-id.path}"
        "mastodon_secret:${config.sops.templates.postiz-mastodon-secret.path}"
        "openai_key:${config.sops.templates.postiz-openai.path}"
      ];
    };

    # Caddy
    vps.caddy.internalPorts.postiz = postizPort;
  };
}
