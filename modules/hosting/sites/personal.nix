{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.hosting.sites.personal;
  personalPort = 4321;

  buildPersonalSite = pkgs.writeShellScript "build-personal-site" ''
    set -euo pipefail
    exec 9>/run/personal-site-source.lock
    ${pkgs.util-linux}/bin/flock --exclusive 9

    if [ ! -d /var/lib/personal-site/.git ]; then
      ${pkgs.git}/bin/git clone --branch main --single-branch https://github.com/rodrgds/personal-website /var/lib/personal-site
    fi
    cd /var/lib/personal-site
    ${pkgs.git}/bin/git fetch --prune origin main
    ${pkgs.git}/bin/git reset --hard origin/main
    ${pkgs.git}/bin/git clean -fd
    ${pkgs.bun}/bin/bun install --frozen-lockfile
    ${pkgs.bun}/bin/bun run build
  '';

  syncPersonalData =
    source:
    pkgs.writeShellScript "sync-personal-data-${source}" ''
      set -euo pipefail
      exec 9>/run/personal-site-source.lock
      ${pkgs.util-linux}/bin/flock --exclusive 9
      cd /var/lib/personal-site
      exec ${pkgs.bun}/bin/bun run personal-data sync --source ${source}
    '';

  reconcilePersonalData = pkgs.writeShellScript "reconcile-personal-data" ''
    set -euo pipefail
    exec 9>/run/personal-site-source.lock
    ${pkgs.util-linux}/bin/flock --exclusive 9
    cd /var/lib/personal-site
    exec ${pkgs.bun}/bin/bun run personal-data sync --source all --full
  '';

  waitForDirectus = pkgs.writeShellScript "wait-for-directus" ''
    set -euo pipefail
    exec ${pkgs.curl}/bin/curl \
      --fail \
      --silent \
      --show-error \
      --retry 60 \
      --retry-all-errors \
      --retry-delay 2 \
      --retry-max-time 120 \
      --max-time 5 \
      http://127.0.0.1:8055/server/health
  '';

  mkSyncService = source: {
    description = "Sync ${source} into the personal Directus store";
    after = [
      "network-online.target"
      "personal-site.service"
      "podman-directus.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.templates."personal-site-env".path;
      WorkingDirectory = "/var/lib/personal-site";
      ExecStartPre = waitForDirectus;
      ExecStart = syncPersonalData source;
      TimeoutStartSec = "30min";
      Nice = 5;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  mkSyncTimer = interval: bootDelay: {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = bootDelay;
      OnUnitActiveSec = interval;
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
  };
in
{
  options.vps.hosting.sites.personal = {
    enable = lib.mkEnableOption "Enable the personal website";
  };

  config = lib.mkIf cfg.enable {
    sops.templates."personal-site-env" = {
      content = ''
        GITHUB_ACCESS_TOKEN=${config.sops.placeholder.website_github_access_token}
        HEVY_API_KEY=${config.sops.placeholder.website_hevy_api_key}
        LASTFM_API_KEY=${config.sops.placeholder.website_lastfm_api_key}
        LASTFM_USERNAME=${config.sops.placeholder.website_lastfm_username}
        TRAKT_CLIENT_ID=${config.sops.placeholder.website_trakt_client_id}
        TRAKT_CLIENT_SECRET=${config.sops.placeholder.website_trakt_client_secret}
        TMDB_API_KEY=${config.sops.placeholder.website_tmdb_api_key}
        DIRECTUS_URL=${config.sops.placeholder.website_directus_url}
        DIRECTUS_INTERNAL_URL=http://127.0.0.1:8055
        DIRECTUS_ACCESS_TOKEN=${config.sops.placeholder.website_directus_access_token}
        PERSONAL_DATA_API_KEY=${config.sops.placeholder.website_personal_data_api_key}
        HOST=127.0.0.1
        PORT=${toString personalPort}
        NODE_ENV=production
      '';
      mode = "0600";
    };

    systemd.services.personal-site = {
      description = "Personal Astro Website Build";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        NODE_OPTIONS = "--max-old-space-size=3072";
        TYPST_PACKAGE_CACHE_PATH = "/var/cache/personal-site/typst";
      };

      path = [
        pkgs.bun
        pkgs.git
        pkgs.nodejs
        pkgs.typst
        pkgs.vips
        pkgs.glib
        pkgs.cairo
        pkgs.pango
        pkgs.util-linux
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = config.sops.templates."personal-site-env".path;
        CacheDirectory = "personal-site";
        StateDirectory = "personal-site";
        WorkingDirectory = "/var/lib/personal-site";
        MemoryHigh = "3G";
        MemoryMax = "4G";

        ExecStart = buildPersonalSite;
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --no-block try-restart personal-site-run.service";
      };
    };

    systemd.services.personal-data-sync-lastfm = mkSyncService "lastfm";
    systemd.services.personal-data-sync-hevy = mkSyncService "hevy";
    systemd.services.personal-data-sync-github = mkSyncService "github";
    systemd.services.personal-data-sync-leetcode = mkSyncService "leetcode";
    systemd.services.personal-data-reconcile = mkSyncService "all" // {
      description = "Reconcile all personal activity sources";
      serviceConfig = (mkSyncService "all").serviceConfig // {
        ExecStart = reconcilePersonalData;
        TimeoutStartSec = "60min";
      };
    };

    systemd.timers = {
      personal-data-sync-lastfm = mkSyncTimer "15min" "5min";
      personal-data-sync-hevy = mkSyncTimer "4h" "15min";
      personal-data-sync-github = mkSyncTimer "6h" "25min";
      personal-data-sync-leetcode = mkSyncTimer "6h" "35min";
      personal-data-reconcile = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun *-*-* 04:00:00";
          Persistent = true;
          RandomizedDelaySec = "20min";
        };
      };
    };

    systemd.services.personal-site-run = {
      description = "Personal Astro Website Server";
      after = [ "personal-site.service" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "personal-site.service" ];

      path = [ pkgs.bun ];

      environment.LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];

      serviceConfig = {
        Type = "simple";
        EnvironmentFile = config.sops.templates."personal-site-env".path;
        StateDirectory = "personal-site";
        WorkingDirectory = "/var/lib/personal-site";
        ExecStart = "${pkgs.bun}/bin/bun run dist/server/entry.mjs";
        Restart = "always";
      };
    };

    vps.caddy.internalPorts = {
      personal = personalPort;
    };

    services.caddy.virtualHosts."rgo.pt" = {
      logFormat = config.vps.caddy.accessLogFor "rgo.pt";
      extraConfig = ''
        handle /_astro/* {
          root * /var/lib/personal-site/dist/client
          header Cache-Control "public, max-age=31536000, immutable"
          file_server
        }

        handle {
          reverse_proxy 127.0.0.1:${toString personalPort}
        }
      '';
    };
  };
}
