# Unprompted - daily reasoning app
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.unprompted;
  runtimeEnvFile = config.sops.templates."unprompted-production-env".path;
  apiImage = "ghcr.io/rodrgds/unprompted-api:latest";
  workerImage = "ghcr.io/rodrgds/unprompted-worker:latest";
  webImage = "ghcr.io/rodrgds/unprompted-web:latest";
  migrateImage = "ghcr.io/rodrgds/unprompted-migrate:latest";
  unpromptedUnits = [
    "podman-unprompted-api.service"
    "podman-unprompted-worker.service"
    "podman-unprompted-web.service"
  ];
  runtimePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gzip
    pkgs.podman
  ];
  initializeScript = pkgs.writeShellScript "unprompted-initialize" ''
    set -euo pipefail
    until ${pkgs.podman}/bin/podman exec unprompted-postgres pg_isready -U unprompted -d unprompted; do
      sleep 2
    done
    ${pkgs.podman}/bin/podman exec -i -u postgres unprompted-postgres \
      psql -U unprompted -d unprompted -v ON_ERROR_STOP=1 <<'SQL'
    \getenv configured_password POSTGRES_PASSWORD
    ALTER ROLE unprompted PASSWORD :'configured_password';
    SQL
    migrate_image_id="$(${pkgs.podman}/bin/podman image inspect ${migrateImage} --format '{{.Id}}')"
    [[ "$migrate_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || {
      echo "verified local Unprompted migration image is unavailable" >&2
      exit 1
    }
    ${pkgs.podman}/bin/podman run --rm --pull=never --network=podman \
      --env-file=${runtimeEnvFile} "$migrate_image_id"
  '';
  bootInitializeScript = pkgs.writeShellScript "unprompted-boot-initialize" ''
    set -euo pipefail
    exec ${pkgs.util-linux}/bin/flock --exclusive /run/podman-maintenance.lock \
      ${initializeScript}
  '';
in
{
  options.vps.unprompted = {
    enable = lib.mkEnableOption "Enable Unprompted";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "unprompted.to";
      description = "Public web domain for Unprompted.";
    };
    apiDomain = lib.mkOption {
      type = lib.types.str;
      default = "api.unprompted.to";
      description = "Public API domain for Unprompted.";
    };
    bootstrapRevision = lib.mkOption {
      type = lib.types.strMatching "^[0-9a-f]{40}$";
      description = "Verified Unprompted revision used to seed an empty local image store.";
    };
    bootstrapDigests = lib.mkOption {
      type = lib.types.submodule {
        options = {
          api = lib.mkOption { type = lib.types.strMatching "^sha256:[0-9a-f]{64}$"; };
          worker = lib.mkOption { type = lib.types.strMatching "^sha256:[0-9a-f]{64}$"; };
          web = lib.mkOption { type = lib.types.strMatching "^sha256:[0-9a-f]{64}$"; };
          migrate = lib.mkOption { type = lib.types.strMatching "^sha256:[0-9a-f]{64}$"; };
        };
      };
      description = "Verified image digests used only when local Unprompted images are absent.";
    };
    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3210;
      description = "Loopback port for the Unprompted web container.";
    };
    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 4100;
      description = "Loopback port for the Unprompted API container.";
    };
    postgresPort = lib.mkOption {
      type = lib.types.port;
      default = 5442;
      description = "Loopback port exposed by the Unprompted Postgres container.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates."unprompted-production-env" = {
      content = ''
        NODE_ENV=production
        PORT=${toString cfg.apiPort}
        API_ORIGIN=http://unprompted-api:${toString cfg.apiPort}
        API_URL=https://${cfg.apiDomain}
        NEXT_PUBLIC_API_URL=https://${cfg.apiDomain}
        EXPO_PUBLIC_API_URL=https://${cfg.apiDomain}

        POSTGRES_USER=unprompted
        POSTGRES_DB=unprompted
        POSTGRES_PASSWORD=${config.sops.placeholder.unprompted_postgres_password}
        POSTGRES_HOST=unprompted-postgres
        POSTGRES_PORT=5432

        BETTER_AUTH_SECRET=${config.sops.placeholder.unprompted_better_auth_secret}
        BETTER_AUTH_URL=https://${cfg.apiDomain}
        WEB_ORIGIN=https://${cfg.domain}

        AI_PROVIDER=openrouter
        AI_API_KEY=${config.sops.placeholder.unprompted_openrouter_api_key}
        AI_BASE_URL=https://openrouter.ai/api/v1
        AI_MODEL=deepseek/deepseek-v4-flash
        AI_EVALUATION_TIMEOUT_MS=30000
        AI_EXTRACTION_PROVIDER=openrouter
        AI_VISION_MODEL=google/gemini-3.5-flash
        AI_EXTRACTION_TIMEOUT_MS=45000
        AI_STT_MODEL=openai/whisper-large-v3-turbo
        AI_STT_TIMEOUT_MS=60000
        AI_STT_MAX_DURATION_SECONDS=300
        EAGER_EVALUATION=false

        SMTP_HOST=smtp.purelymail.com
        SMTP_PORT=465
        SMTP_SECURE=true
        SMTP_USERNAME=hello@unprompted.to
        SMTP_PASSWORD=${config.sops.placeholder.unprompted_smtp_password}
        EMAIL_FROM="Unprompted <hello@unprompted.to>"
        EMAIL_TOKEN_SECRET=${config.sops.placeholder.unprompted_email_token_secret}

        DISCUSSIONS_ENABLED=false
        EXTRACTION_ENABLED=false
        NOTIFICATIONS_ENABLED=false
        API_VERSION=1.0.0
        MIN_WEB_VERSION=0.1.0
        MIN_NATIVE_VERSION=0.1.0
        OPERATIONS_TOKEN=${config.sops.placeholder.unprompted_operations_token}
      '';
      mode = "0400";
      restartUnits = [
        "unprompted-initialize.service"
      ]
      ++ unpromptedUnits;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/unprompted 0750 root root -"
      "d /var/lib/unprompted/deploy-deliveries 0700 root root -"
      "d /var/lib/unprompted/postgres 0700 70 70 -"
      "d /var/backup/unprompted 0750 root root -"
    ];

    virtualisation.oci-containers.containers = {
      unprompted-postgres = {
        image = "docker.io/library/postgres:17-alpine@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193";
        environment = {
          POSTGRES_USER = "unprompted";
          POSTGRES_DB = "unprompted";
        };
        environmentFiles = [ runtimeEnvFile ];
        volumes = [ "/var/lib/unprompted/postgres:/var/lib/postgresql/data" ];
        ports = [ "127.0.0.1:${toString cfg.postgresPort}:5432" ];
        extraOptions = [
          "--network=podman"
          "--health-cmd=pg_isready -U unprompted -d unprompted"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=12"
        ];
      };
      unprompted-api = {
        image = apiImage;
        environmentFiles = [ runtimeEnvFile ];
        ports = [ "127.0.0.1:${toString cfg.apiPort}:${toString cfg.apiPort}" ];
        dependsOn = [ "unprompted-postgres" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
        ];
      };
      unprompted-worker = {
        image = workerImage;
        environmentFiles = [ runtimeEnvFile ];
        dependsOn = [ "unprompted-postgres" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
        ];
      };
      unprompted-web = {
        image = webImage;
        environmentFiles = [ runtimeEnvFile ];
        environment = {
          HOSTNAME = "0.0.0.0";
          PORT = "3000";
          NEXT_TELEMETRY_DISABLED = "1";
        };
        ports = [ "127.0.0.1:${toString cfg.webPort}:3000" ];
        dependsOn = [ "unprompted-api" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
        ];
      };
    };

    systemd.services.podman-unprompted-postgres = {
      unitConfig.ConditionPathExists = runtimeEnvFile;
    };

    systemd.services.unprompted-images = {
      description = "Seed and verify local Unprompted production images";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [ "unprompted-initialize.service" ] ++ unpromptedUnits;
      requiredBy = [ "unprompted-initialize.service" ] ++ unpromptedUnits;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "unprompted-images" ''
          set -euo pipefail
          exec 9>/run/podman-maintenance.lock
          ${pkgs.util-linux}/bin/flock --exclusive 9

          components=(
            "api|ghcr.io/rodrgds/unprompted-api|${cfg.bootstrapDigests.api}"
            "worker|ghcr.io/rodrgds/unprompted-worker|${cfg.bootstrapDigests.worker}"
            "web|ghcr.io/rodrgds/unprompted-web|${cfg.bootstrapDigests.web}"
            "migrate|ghcr.io/rodrgds/unprompted-migrate|${cfg.bootstrapDigests.migrate}"
          )

          present_count=0
          for entry in "''${components[@]}"; do
            IFS='|' read -r component image digest <<< "$entry"
            if ${pkgs.podman}/bin/podman image exists "$image:latest"; then
              present_count=$((present_count + 1))
            fi
          done

          if [ "$present_count" -eq 0 ]; then
            ${pkgs.systemd}/bin/systemctl restart packages-registry-login.service
            for entry in "''${components[@]}"; do
              IFS='|' read -r component image digest <<< "$entry"
              candidate="$image@$digest"
              ${pkgs.podman}/bin/podman pull "$candidate"
              image_revision="$(${pkgs.podman}/bin/podman image inspect "$candidate" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
              [ "$image_revision" = "${cfg.bootstrapRevision}" ] || {
                echo "$component bootstrap revision $image_revision does not match ${cfg.bootstrapRevision}" >&2
                exit 1
              }
            done
            for entry in "''${components[@]}"; do
              IFS='|' read -r component image digest <<< "$entry"
              ${pkgs.podman}/bin/podman tag "$image@$digest" "$image:latest"
            done
          elif [ "$present_count" -ne "''${#components[@]}" ]; then
            echo "local Unprompted image set is incomplete; refusing an automatic bootstrap downgrade" >&2
            exit 1
          fi

          active_revision=""
          for entry in "''${components[@]}"; do
            IFS='|' read -r component image digest <<< "$entry"
            image_revision="$(${pkgs.podman}/bin/podman image inspect "$image:latest" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
            [[ "$image_revision" =~ ^[0-9a-f]{40}$ ]] || {
              echo "$component local image has an invalid revision label" >&2
              exit 1
            }
            if [ -z "$active_revision" ]; then
              active_revision="$image_revision"
            elif [ "$image_revision" != "$active_revision" ]; then
              echo "local Unprompted images do not share one revision" >&2
              exit 1
            fi
          done
        '';
      };
    };

    systemd.services.unprompted-initialize = {
      description = "Synchronize and migrate the Unprompted database at boot";
      after = [
        "podman-unprompted-postgres.service"
        "unprompted-images.service"
      ];
      requires = [
        "podman-unprompted-postgres.service"
        "unprompted-images.service"
      ];
      before = unpromptedUnits;
      requiredBy = [
        "podman-unprompted-api.service"
        "podman-unprompted-worker.service"
      ];
      unitConfig.ConditionPathExists = runtimeEnvFile;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = runtimeEnvFile;
        TimeoutStartSec = "15min";
        ExecStart = bootInitializeScript;
      };
    };

    systemd.services.unprompted-deploy-initialize = {
      description = "Migrate Unprompted before replacing running application containers";
      # The parent deployment unit already owns the maintenance lock and has
      # pulled, verified, and promoted the complete candidate image set. Do not
      # depend on unprompted-images here: starting that locked boot unit from
      # inside the locked deployment would deadlock if it were inactive.
      after = [ "podman-unprompted-postgres.service" ];
      requires = [ "podman-unprompted-postgres.service" ];
      unitConfig.ConditionPathExists = runtimeEnvFile;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = runtimeEnvFile;
        TimeoutStartSec = "15min";
        ExecStart = initializeScript;
      };
    };

    systemd.services.podman-unprompted-api = {
      after = [ "unprompted-initialize.service" ];
      requires = [ "unprompted-initialize.service" ];
    };
    systemd.services.podman-unprompted-worker = {
      after = [ "unprompted-initialize.service" ];
      requires = [ "unprompted-initialize.service" ];
    };
    systemd.services.podman-unprompted-web = {
      after = [
        "unprompted-initialize.service"
        "podman-unprompted-api.service"
      ];
      requires = [
        "unprompted-initialize.service"
        "podman-unprompted-api.service"
      ];
    };

    systemd.services.unprompted-postgres-backup = {
      description = "Back up the Unprompted PostgreSQL database";
      after = [ "podman-unprompted-postgres.service" ];
      requires = [ "podman-unprompted-postgres.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "unprompted-postgres-backup" ''
          set -euo pipefail
          export PATH=${runtimePath}:$PATH
          timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
          destination="/var/backup/unprompted/postgres-$timestamp.sql.gz"
          temporary="$destination.tmp"
          trap 'rm -f "$temporary"' EXIT
          podman exec unprompted-postgres \
            pg_dump --username unprompted --dbname unprompted --no-owner --no-privileges \
            | gzip --best > "$temporary"
          gzip --test "$temporary"
          mv "$temporary" "$destination"
          trap - EXIT
          find /var/backup/unprompted -type f -name 'postgres-*.sql.gz' -mtime +14 -delete
        '';
      };
    };

    systemd.timers.unprompted-postgres-backup = {
      description = "Back up Unprompted PostgreSQL daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:45:00";
        Persistent = true;
        RandomizedDelaySec = "20m";
        Unit = "unprompted-postgres-backup.service";
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.domain}".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.webPort}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
      "www.${cfg.domain}".extraConfig = ''
        redir https://${cfg.domain}{uri} permanent
      '';
      "${cfg.apiDomain}".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.apiPort}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };
  };
}
