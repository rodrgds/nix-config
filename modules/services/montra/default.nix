{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.montra;
  postgresUser = "montra";
  postgresDatabase = "montra";
  apiPort = 8788;
  webPort = 8091;
  apiImage = "ghcr.io/rodrgds/montra-api:latest";
in
{
  options.vps.montra = {
    enable = lib.mkEnableOption "Enable Montra";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "montra.style";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/montra 0750 root root -"
      "d /var/lib/montra/postgres 0700 70 70 -"
      "d /var/lib/montra/meilisearch 0750 1000 1000 -"
      "d /var/lib/montra/bootstrap 0750 root root -"
      "d /var/backup/montra 0750 root root -"
    ];

    sops.templates = {
      "montra-registry-token" = {
        content = config.sops.placeholder.montra_ghcr_token;
        mode = "0400";
      };
      "montra-postgres-env" = {
        content = ''
          POSTGRES_USER=${postgresUser}
          POSTGRES_DB=${postgresDatabase}
          POSTGRES_PASSWORD=${config.sops.placeholder.montra_postgres_password}
        '';
        mode = "0400";
      };
      "montra-env" = {
        content = ''
          NODE_ENV=production
          DATABASE_URL=postgres://${postgresUser}:${config.sops.placeholder.montra_postgres_password}@montra-postgres:5432/${postgresDatabase}
          BETTER_AUTH_SECRET=${config.sops.placeholder.montra_better_auth_secret}
          WEB_ORIGIN=https://${cfg.domain}
          API_ORIGIN=https://${cfg.domain}
          ADMIN_EMAILS=${config.sops.placeholder.montra_admin_emails}
          AI_PROVIDER=openrouter
          OPENROUTER_API_KEY=${config.sops.placeholder.montra_openrouter_api_key}
          SEARCH_PROVIDER=meilisearch
          CATALOG_PREWARM=1
          ADMIN_EMBEDDED_JOB_WORKER=0
          MEILI_HOST=http://montra-meilisearch:7700
          MEILI_MASTER_KEY=${config.sops.placeholder.montra_meili_master_key}
          VISUAL_SEARCH_PROVIDER=external
          VISUAL_INDEX_BACKEND=postgres
          VISUAL_EMBEDDING_URL=http://montra-embedding:8811/embed-image
          VISUAL_EMBEDDING_MODEL=openai/clip-vit-base-patch32
          OBJECT_STORAGE_PROVIDER=r2
          OBJECT_STORAGE_ENDPOINT=https://1e84f0262ece6e76da6df50801960036.r2.cloudflarestorage.com
          OBJECT_STORAGE_REGION=auto
          OBJECT_STORAGE_BUCKET=montra
          OBJECT_STORAGE_ACCESS_KEY=${config.sops.placeholder.montra_r2_access_key_id}
          OBJECT_STORAGE_SECRET_KEY=${config.sops.placeholder.montra_r2_secret_access_key}
          OBJECT_STORAGE_PUBLIC_URL=https://media.${cfg.domain}
        '';
        mode = "0400";
      };
      "montra-meili-env" = {
        content = ''
          MEILI_ENV=production
          MEILI_NO_ANALYTICS=true
          MEILI_MASTER_KEY=${config.sops.placeholder.montra_meili_master_key}
        '';
        mode = "0400";
      };
    };

    systemd.services.montra-registry-login = {
      description = "Authenticate Podman to Montra's private GHCR packages";
      before = [
        "podman-montra-postgres.service"
        "podman-montra-embedding.service"
        "podman-montra-api.service"
        "podman-montra-worker.service"
        "podman-montra-web.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "montra-registry-login" ''
          exec ${pkgs.podman}/bin/podman login ghcr.io --username rodrgds --password-stdin < ${config.sops.templates.montra-registry-token.path}
        '';
      };
    };

    systemd.services.podman-montra-postgres = {
      after = [ "montra-registry-login.service" ];
      requires = [ "montra-registry-login.service" ];
    };
    systemd.services.podman-montra-embedding = {
      after = [ "montra-registry-login.service" ];
      requires = [ "montra-registry-login.service" ];
    };
    systemd.services.podman-montra-api = {
      after = [ "montra-registry-login.service" ];
      requires = [ "montra-registry-login.service" ];
    };
    systemd.services.podman-montra-worker = {
      after = [ "montra-registry-login.service" ];
      requires = [ "montra-registry-login.service" ];
    };
    systemd.services.podman-montra-web = {
      after = [ "montra-registry-login.service" ];
      requires = [ "montra-registry-login.service" ];
    };

    virtualisation.oci-containers.containers = {
      montra-postgres = {
        image = "ghcr.io/rodrgds/montra-postgres:latest";
        environmentFiles = [ config.sops.templates.montra-postgres-env.path ];
        volumes = [ "/var/lib/montra/postgres:/var/lib/postgresql/data" ];
        extraOptions = [
          "--network=podman"
          "--pull=always"
          "--shm-size=1g"
          "--health-cmd=pg_isready -U montra -d montra"
          "--health-interval=10s"
          "--health-retries=18"
        ];
      };
      montra-meilisearch = {
        image = "docker.io/getmeili/meilisearch:v1.16";
        environmentFiles = [ config.sops.templates.montra-meili-env.path ];
        volumes = [ "/var/lib/montra/meilisearch:/meili_data" ];
        extraOptions = [
          "--network=podman"
          "--health-cmd=wget --spider http://127.0.0.1:7700/health"
          "--health-interval=10s"
          "--health-retries=18"
        ];
      };
      montra-embedding = {
        image = "ghcr.io/rodrgds/montra-embedding:latest";
        extraOptions = [
          "--network=podman"
          "--pull=always"
          "--health-cmd=python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8811/health')\""
          "--health-interval=30s"
          "--health-retries=10"
          "--memory=3g"
        ];
      };
      montra-api = {
        image = apiImage;
        environmentFiles = [ config.sops.templates.montra-env.path ];
        ports = [ "127.0.0.1:${toString apiPort}:8787" ];
        dependsOn = [
          "montra-postgres"
          "montra-meilisearch"
          "montra-embedding"
        ];
        extraOptions = [
          "--network=podman"
          "--pull=always"
          "--health-cmd=bun -e \"const r=await fetch('http://127.0.0.1:8787/health/ready');process.exit(r.ok?0:1)\""
          "--health-interval=15s"
          "--health-retries=12"
          "--memory=3g"
        ];
      };
      montra-worker = {
        image = apiImage;
        cmd = [
          "bun"
          "run"
          "admin:worker"
        ];
        environmentFiles = [ config.sops.templates.montra-env.path ];
        dependsOn = [
          "montra-postgres"
          "montra-meilisearch"
          "montra-embedding"
        ];
        extraOptions = [
          "--network=podman"
          "--pull=always"
          "--memory=1g"
        ];
      };
      montra-web = {
        image = "ghcr.io/rodrgds/montra-web:latest";
        ports = [ "127.0.0.1:${toString webPort}:3000" ];
        dependsOn = [ "montra-api" ];
        extraOptions = [
          "--network=podman"
          "--pull=always"
          "--memory=512m"
        ];
      };
    };

    systemd.services.montra-initialize = {
      description = "Restore, migrate, and index the Montra catalog";
      after = [
        "podman-montra-postgres.service"
        "podman-montra-meilisearch.service"
        "montra-registry-login.service"
      ];
      before = [
        "podman-montra-api.service"
        "podman-montra-worker.service"
      ];
      requiredBy = [
        "podman-montra-api.service"
        "podman-montra-worker.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "infinity";
        ExecStart = pkgs.writeShellScript "montra-initialize" ''
          set -euo pipefail
          until ${pkgs.podman}/bin/podman exec montra-postgres pg_isready -U ${postgresUser} -d ${postgresDatabase}; do sleep 2; done
          if [ -f /var/lib/montra/bootstrap/montra.dump ] && ! ${pkgs.podman}/bin/podman exec montra-postgres psql -U ${postgresUser} -d ${postgresDatabase} -Atqc "select to_regclass('public.product') is not null" | ${pkgs.gnugrep}/bin/grep -qx t; then
            ${pkgs.podman}/bin/podman exec -i montra-postgres pg_restore -U ${postgresUser} -d ${postgresDatabase} --no-owner --no-acl < /var/lib/montra/bootstrap/montra.dump
            touch /var/lib/montra/bootstrap/.needs-search-index
          fi
          ${pkgs.podman}/bin/podman run --rm --network=podman --env-file=${config.sops.templates.montra-env.path} ${apiImage} bun run db:migrate
          if [ -f /var/lib/montra/bootstrap/.needs-search-index ]; then
            ${pkgs.podman}/bin/podman run --rm --network=podman --env-file=${config.sops.templates.montra-env.path} ${apiImage} bun run index:search
            rm -f /var/lib/montra/bootstrap/.needs-search-index
          fi
        '';
      };
    };

    systemd.services.montra-postgres-backup = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "montra-postgres-backup" ''
          set -euo pipefail
          stamp=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          ${pkgs.podman}/bin/podman exec montra-postgres pg_dump -U ${postgresUser} -d ${postgresDatabase} | ${pkgs.gzip}/bin/gzip > /var/backup/montra/montra_$stamp.sql.gz
          ${pkgs.findutils}/bin/find /var/backup/montra -name 'montra_*.sql.gz' -mtime +3 -delete
        '';
      };
    };
    systemd.timers.montra-postgres-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      encode zstd gzip
      handle /api/* {
        reverse_proxy 127.0.0.1:${toString apiPort}
      }
      handle /health/* {
        reverse_proxy 127.0.0.1:${toString apiPort}
      }
      handle {
        reverse_proxy 127.0.0.1:${toString webPort}
      }
    '';
  };
}
