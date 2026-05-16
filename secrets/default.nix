# Secrets management with sops-nix
{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.secrets;
  inherit (constants) homeDir isLinux isDarwin;

  # Determine secrets file and list based on host type
  vpsSecretsFile = ./vps-secrets.yaml;
  mainSecretsFile = ./secrets.yaml;
  secretsFile = if cfg.isVps then vpsSecretsFile else mainSecretsFile;

  vpsSecretNames = [
    # N8N
    "n8n_encryption_key"
    # Uni Easy (separate postgres project)
    "unieasy_postgres_user"
    "unieasy_postgres_password"
    "unieasy_postgres_db"
    # Umami
    "umami_db_user"
    "umami_db_password"
    "umami_db_name"
    "umami_app_secret"
    # Ghost
    "ghost_db_user"
    "ghost_db_password"
    "ghost_db_root_password"
    "ghost_db_name"
    "ghost_mailgun_user"
    "ghost_mailgun_password"
    # Vaultwarden
    "vaultwarden_admin_token"
    # Shlink
    "shlink_db_password"
    "shlink_db_user"
    "shlink_db_name"
    "shlink_geolite_license_key"
    # YOURLS
    "yourls_db_user"
    "yourls_db_password"
    "yourls_db_root_password"
    "yourls_admin_password"
    "yourls_admin_user"
    # Postiz
    "postiz_jwt_secret"
    "postiz_postgres_password"
    "postiz_redis_password"
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
    # Directus CMS
    "directus_key"
    "directus_secret"
    "directus_admin_email"
    "directus_admin_password"
    "directus_db_user"
    "directus_db_password"
    "directus_db_name"
    # TRNDb Directus CMS
    "trndb_key"
    "trndb_secret"
    "trndb_admin_email"
    "trndb_admin_password"
    "trndb_db_user"
    "trndb_db_password"
    "trndb_db_name"
    # Website
    "website_hevy_api_key"
    "website_lastfm_api_key"
    "website_lastfm_username"
    "website_trakt_client_id"
    "website_trakt_client_secret"
    "website_tmdb_api_key"
    "website_directus_url"
    "website_directus_access_token"
    # OpenClaw
    # "openclaw_telegram_token"
    # "openclaw_zai_api_key"
    # "openclaw_gateway_token"
    # OpenPost
    "openpost_jwt_secret"
    "openpost_encryption_key"
    "openpost_twitter_client_id"
    "openpost_twitter_client_secret"
    "openpost_linkedin_client_id"
    "openpost_linkedin_client_secret"
    "openpost_threads_client_id"
    "openpost_threads_client_secret"
    "openpost_mastodon_servers"
  ];

  mainSecretNames = [
    "lastfm_api_key"
    "lastfm_secret"
    "lastfm_username"
    "openrouter_api_key"
    "openai_api_key"
    "location_latitude"
    "location_longitude"
    "context7_api_key"
    "exa_api_key"
    "github_pat"
    "ngrok_auth_token"
  ];

  # Build secrets attrset from list of names
  buildSecrets = names: lib.listToAttrs (map (name: lib.nameValuePair name { }) names);

  # OpenClaw secrets need to be readable by the user
  # openclawSecrets = {
  #   openclaw_telegram_token = {
  #     owner = username;
  #     group = "users";
  #     mode = "0400";
  #   };
  #   openclaw_zai_api_key = {
  #     owner = username;
  #     group = "users";
  #     mode = "0400";
  #   };
  #   openclaw_gateway_token = {
  #     owner = username;
  #     group = "users";
  #     mode = "0400";
  #   };
  # };
in
{
  options.secrets = {
    enable = lib.mkEnableOption "Enable secrets management with sops-nix";
    isVps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use VPS-specific secrets file";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # System-level sops configuration (for VPS services)
      # Only available on NixOS/Linux - darwin doesn't have system-level sops
      (lib.optionalAttrs isLinux (
        lib.mkIf cfg.isVps {
          sops = {
            age.keyFile = "/root/.config/sops/age/keys.txt";
            defaultSopsFile = vpsSecretsFile;
            secrets = buildSecrets vpsSecretNames;
          };
        }
      ))

      # Home-manager sops configuration for personal machines.
      # VPS doesn't need HM sops - system-level sops handles all VPS secrets,
      # and the user-level service can't read /root/.config/sops/age/keys.txt.
      (lib.mkIf (!cfg.isVps) {
        home-manager.users.${username} =
          { config, ... }:
          {
            sops = {
              age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
              defaultSopsFile = mainSecretsFile;
              secrets = buildSecrets mainSecretNames;
            };
          };
      })
    ]
  );
}
