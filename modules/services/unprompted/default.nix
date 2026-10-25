# Unprompted - daily reasoning app
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.unprompted;
  postgresEnvFile = config.sops.templates."unprompted-postgres-env".path;
  migrateEnvFile = config.sops.templates."unprompted-migrate-env".path;
  apiEnvFile = config.sops.templates."unprompted-api-env".path;
  workerEnvFile = config.sops.templates."unprompted-worker-env".path;
  # Share values at their owner, but grant each runtime only its own credentials.
  postgresEnvironment = ''
    POSTGRES_USER=unprompted_cluster_admin
    POSTGRES_DB=unprompted
    POSTGRES_PASSWORD=${config.sops.placeholder.unprompted_postgres_admin_password}
    APP_POSTGRES_PASSWORD=${config.sops.placeholder.unprompted_postgres_password}
  '';
  databaseEnvironment = ''
    POSTGRES_USER=unprompted
    POSTGRES_DB=unprompted
    POSTGRES_PASSWORD=${config.sops.placeholder.unprompted_postgres_password}
    NODE_ENV=production
    POSTGRES_HOST=unprompted-postgres
    POSTGRES_PORT=5432
  '';
  evaluationEnvironment = ''
    AI_PROVIDER=openrouter
    AI_API_KEY=${config.sops.placeholder.unprompted_openrouter_api_key}
    AI_BASE_URL=https://openrouter.ai/api/v1
    AI_MODEL=deepseek/deepseek-v4-flash
    AI_EVALUATION_TIMEOUT_MS=30000
  '';
  emailEnvironment = ''
    SMTP_HOST=smtp.purelymail.com
    SMTP_PORT=465
    SMTP_SECURE=true
    SMTP_USERNAME=hello@unprompted.to
    SMTP_PASSWORD=${config.sops.placeholder.unprompted_smtp_password}
    EMAIL_FROM="Unprompted <hello@unprompted.to>"
    EMAIL_TOKEN_SECRET=${config.sops.placeholder.unprompted_email_token_secret}
  '';
  operationsEnvironment = ''
    OPERATIONS_TOKEN=${config.sops.placeholder.unprompted_operations_token}
  '';
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
    # Local socket access is restricted to the PostgreSQL container. Existing
    # clusters initially have only the old bootstrap login; fresh ones have admin.
    initial_role=unprompted_cluster_admin
    if ! ${pkgs.podman}/bin/podman exec -u postgres unprompted-postgres \
      psql -X -U unprompted_cluster_admin -d unprompted -Atqc 'SELECT 1' >/dev/null 2>&1; then
      initial_role=unprompted
    fi
    ${pkgs.podman}/bin/podman exec -i -u postgres unprompted-postgres \
      psql -X -q -U "$initial_role" -d unprompted -v ON_ERROR_STOP=1 -v VERBOSITY=terse <<'SQL'
    BEGIN;
    -- The application owns the database and can persist its search_path. Never
    -- resolve privileged catalog access through app-owned schemas or temp tables.
    SET LOCAL search_path = pg_catalog, pg_temp;
    -- Do not log password-bearing statements, even on an initialization error.
    SET LOCAL log_statement = 'none';
    SET LOCAL log_min_error_statement = 'panic';
    \getenv admin_password POSTGRES_PASSWORD
    \getenv application_password APP_POSTGRES_PASSWORD
    SELECT NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'unprompted_cluster_admin') AS needs_admin \gset
    \if :needs_admin
      SELECT oid = 10 AS is_bootstrap FROM pg_roles WHERE rolname = 'unprompted' \gset
      \if :is_bootstrap
        -- PostgreSQL forbids demoting OID 10 or renaming the session user.
        -- A transaction-local NOLOGIN helper permits the rename without leaving
        -- a third role, or moving ownership of template/system objects to the app.
        CREATE ROLE unprompted_role_transition SUPERUSER NOLOGIN;
        SET SESSION AUTHORIZATION unprompted_role_transition;
        ALTER ROLE unprompted RENAME TO unprompted_cluster_admin;
        SET SESSION AUTHORIZATION unprompted_cluster_admin;
        DROP ROLE unprompted_role_transition;
      \else
        CREATE ROLE unprompted_cluster_admin SUPERUSER LOGIN;
        SET SESSION AUTHORIZATION unprompted_cluster_admin;
      \endif
    \endif
    SELECT NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'unprompted') AS needs_application \gset
    \if :needs_application
      CREATE ROLE unprompted LOGIN;
    \endif
    ALTER ROLE unprompted_cluster_admin SUPERUSER LOGIN PASSWORD :'admin_password';
    ALTER ROLE unprompted LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'application_password';
    ALTER DATABASE unprompted OWNER TO unprompted;
    -- Scope ownership to the application's schemas in this database. Never
    -- REASSIGN OWNED from the bootstrap role: it also owns shared/system objects.
    DO $ownership$
    DECLARE item record;
    BEGIN
      FOR item IN SELECT nspname FROM pg_namespace
        WHERE nspname IN ('public', 'drizzle', 'pgboss')
          AND nspowner = 'unprompted_cluster_admin'::regrole
      LOOP
        EXECUTE format('ALTER SCHEMA %I OWNER TO unprompted', item.nspname);
      END LOOP;
      FOR item IN SELECT n.nspname, c.relname, c.relkind FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('public', 'drizzle', 'pgboss')
          AND c.relowner = 'unprompted_cluster_admin'::regrole
          AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
        ORDER BY c.relkind = 'S'
      LOOP
        EXECUTE format('ALTER %s %I.%I OWNER TO unprompted',
          CASE item.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW'
            WHEN 'm' THEN 'MATERIALIZED VIEW' WHEN 'f' THEN 'FOREIGN TABLE' ELSE 'TABLE' END,
          item.nspname, item.relname);
      END LOOP;
      FOR item IN SELECT p.oid::regprocedure AS signature FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('public', 'drizzle', 'pgboss')
          AND p.proowner = 'unprompted_cluster_admin'::regrole
      LOOP
        EXECUTE format('ALTER ROUTINE %s OWNER TO unprompted', item.signature);
      END LOOP;
      FOR item IN SELECT n.nspname, t.typname, t.typtype FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        LEFT JOIN pg_class c ON c.oid = t.typrelid
        WHERE n.nspname IN ('public', 'drizzle', 'pgboss')
          AND t.typowner = 'unprompted_cluster_admin'::regrole
          AND (t.typtype IN ('e', 'd', 'r') OR (t.typtype = 'c' AND c.relkind = 'c'))
      LOOP
        EXECUTE format('ALTER %s %I.%I OWNER TO unprompted',
          CASE item.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
          item.nspname, item.typname);
      END LOOP;
    END
    $ownership$;
    COMMIT;
    SQL
    migrate_image_id="$(${pkgs.podman}/bin/podman image inspect ${migrateImage} --format '{{.Id}}')"
    [[ "$migrate_image_id" =~ ^(sha256:)?[0-9a-f]{64}$ ]] || {
      echo "verified local Unprompted migration image is unavailable" >&2
      exit 1
    }
    ${pkgs.podman}/bin/podman run --rm --pull=never --network=podman \
      --user=1000:1000 --cap-drop=ALL --security-opt=no-new-privileges \
      --env-file=${migrateEnvFile} "$migrate_image_id"
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
    sops.secrets = lib.genAttrs [
      "unprompted_postgres_password"
      "unprompted_postgres_admin_password"
      "unprompted_better_auth_secret"
      "unprompted_openrouter_api_key"
      "unprompted_smtp_password"
      "unprompted_email_token_secret"
      "unprompted_operations_token"
    ] (_: { });

    sops.templates = {
      "unprompted-postgres-env" = {
        content = postgresEnvironment;
        mode = "0400";
        restartUnits = [
          "podman-unprompted-postgres.service"
          "unprompted-initialize.service"
        ];
      };
      "unprompted-migrate-env" = {
        content = databaseEnvironment;
        mode = "0400";
        restartUnits = [ "unprompted-initialize.service" ];
      };
      "unprompted-api-env" = {
        content =
          databaseEnvironment
          + evaluationEnvironment
          + emailEnvironment
          + operationsEnvironment
          + ''
            PORT=${toString cfg.apiPort}
            BETTER_AUTH_SECRET=${config.sops.placeholder.unprompted_better_auth_secret}
            BETTER_AUTH_URL=https://${cfg.apiDomain}
            WEB_ORIGIN=https://${cfg.domain}
            AI_EXTRACTION_PROVIDER=openrouter
            AI_VISION_MODEL=google/gemini-3.5-flash
            AI_EXTRACTION_TIMEOUT_MS=45000
            AI_STT_MODEL=openai/whisper-large-v3-turbo
            AI_STT_TIMEOUT_MS=60000
            AI_STT_MAX_DURATION_SECONDS=300
            EAGER_EVALUATION=false

            DISCUSSIONS_ENABLED=false
            EXTRACTION_ENABLED=false
            NOTIFICATIONS_ENABLED=false
            API_VERSION=1.0.0
            MIN_WEB_VERSION=0.1.0
            MIN_NATIVE_VERSION=0.1.0
          '';
        mode = "0400";
        restartUnits = [ "podman-unprompted-api.service" ];
      };
      "unprompted-worker-env" = {
        # EMAIL_TOKEN_SECRET is explicit, so the worker needs no auth-signing fallback.
        content =
          databaseEnvironment
          + evaluationEnvironment
          + emailEnvironment
          + operationsEnvironment
          + ''
            API_ORIGIN=http://unprompted-api:${toString cfg.apiPort}
            WEB_ORIGIN=https://${cfg.domain}
            NOTIFICATIONS_ENABLED=false
          '';
        mode = "0400";
        restartUnits = [ "podman-unprompted-worker.service" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/unprompted 0750 root root -"
      "d /var/lib/unprompted/deploy-deliveries 0700 root root -"
      "d /var/lib/unprompted/postgres 0700 70 70 -"
      "d /var/backup/unprompted 0750 root root -"
    ];

    virtualisation.oci-containers.containers = {
      unprompted-postgres = {
        # Wait for pg_isready before boot migrations or deployment acceptance.
        podman.sdnotify = "healthy";
        image = "docker.io/library/postgres:17-alpine@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193";
        environmentFiles = [ postgresEnvFile ];
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
        user = "1000:1000";
        environmentFiles = [ apiEnvFile ];
        ports = [ "127.0.0.1:${toString cfg.apiPort}:${toString cfg.apiPort}" ];
        dependsOn = [ "unprompted-postgres" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
        ];
      };
      unprompted-worker = {
        image = workerImage;
        user = "1000:1000";
        environmentFiles = [ workerEnvFile ];
        dependsOn = [ "unprompted-postgres" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
        ];
      };
      unprompted-web = {
        image = webImage;
        user = "1000:1000";
        # The standalone Next server only needs public routing configuration.
        # Keep this out of SOPS so no credential file is granted to the web tier.
        environment = {
          NODE_ENV = "production";
          API_URL = "https://${cfg.apiDomain}";
          NEXT_PUBLIC_API_URL = "https://${cfg.apiDomain}";
          WEB_ORIGIN = "https://${cfg.domain}";
          HOSTNAME = "0.0.0.0";
          PORT = "3000";
          NEXT_TELEMETRY_DISABLED = "1";
        };
        ports = [ "127.0.0.1:${toString cfg.webPort}:3000" ];
        dependsOn = [ "unprompted-api" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
          # Next image optimization writes here. Do not grant writes to /app.
          "--tmpfs=/app/apps/web/.next/cache:rw,mode=1777,size=128m"
        ];
      };
    };

    systemd.services.podman-unprompted-postgres = {
      unitConfig.ConditionPathExists = postgresEnvFile;
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
      unitConfig.ConditionPathExists = migrateEnvFile;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = migrateEnvFile;
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
      unitConfig.ConditionPathExists = migrateEnvFile;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = migrateEnvFile;
        TimeoutStartSec = "15min";
        ExecStart = initializeScript;
      };
    };

    systemd.services.podman-unprompted-api = {
      # Existing sessions keep the bootstrap role's OID across its rename.
      # Reconnect both app processes when the role transition changes.
      restartTriggers = [ initializeScript ];
      after = [ "unprompted-initialize.service" ];
      requires = [ "unprompted-initialize.service" ];
    };
    systemd.services.podman-unprompted-worker = {
      restartTriggers = [ initializeScript ];
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
      "${cfg.domain}" = {
        logFormat = config.vps.caddy.accessLogFor cfg.domain;
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.webPort}

          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            X-Content-Type-Options "nosniff"
            X-Frame-Options "SAMEORIGIN"
            Referrer-Policy "strict-origin-when-cross-origin"
          }
        '';
      };
      "www.${cfg.domain}" = {
        logFormat = config.vps.caddy.accessLogFor "www.${cfg.domain}";
        extraConfig = ''
          redir https://${cfg.domain}{uri} permanent
        '';
      };
      "${cfg.apiDomain}" = {
        logFormat = config.vps.caddy.accessLogFor cfg.apiDomain;
        extraConfig = ''
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
  };
}
