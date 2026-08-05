# Unprompted - daily reasoning app
# https://github.com/rodrgds/unprompted
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.unprompted;

  repoDir = "/var/lib/unprompted/repo";
  runtimeDir = "/var/lib/unprompted/runtime";
  runtimeEnvFile = config.sops.templates."unprompted-production-env".path;
  envExample = ''
    # Reference only. Production values come from the root-only SOPS template.
    # Keep this file shell/systemd EnvironmentFile compatible: quote values containing spaces.
    NODE_ENV=production
    PORT=${toString cfg.apiPort}
    API_ORIGIN=http://127.0.0.1:${toString cfg.apiPort}
    API_URL=https://${cfg.apiDomain}
    NEXT_PUBLIC_API_URL=https://${cfg.apiDomain}
    EXPO_PUBLIC_API_URL=https://${cfg.apiDomain}
    EXPO_PUBLIC_EAS_PROJECT_ID=

    POSTGRES_USER=unprompted
    POSTGRES_DB=unprompted
    POSTGRES_PASSWORD=replace-with-db-password
    DATABASE_URL=postgres://unprompted:replace-with-db-password@127.0.0.1:${toString cfg.postgresPort}/unprompted

    BETTER_AUTH_SECRET=replace-with-rotatable-32-plus-character-secret
    BETTER_AUTH_URL=https://${cfg.apiDomain}
    WEB_ORIGIN=https://${cfg.domain}
    GOOGLE_CLIENT_ID=
    GOOGLE_CLIENT_SECRET=

    AI_PROVIDER=openrouter
    AI_API_KEY=replace-with-openrouter-api-key
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

    RESEND_API_KEY=
    EMAIL_FROM="Unprompted <hello@${cfg.domain}>"
    EMAIL_TOKEN_SECRET=replace-with-rotatable-32-plus-character-secret
    RESEND_WEBHOOK_SECRET=

    EXPO_ACCESS_TOKEN=
    S3_ENDPOINT=
    S3_REGION=auto
    S3_BUCKET=
    S3_ACCESS_KEY_ID=
    S3_SECRET_ACCESS_KEY=

    DISCUSSIONS_ENABLED=false
    DISCUSSIONS_DISABLED_PROBLEM_SLUGS=
    EXTRACTION_ENABLED=false
    NOTIFICATIONS_ENABLED=false
    API_VERSION=1.0.0
    MIN_WEB_VERSION=0.1.0
    MIN_NATIVE_VERSION=0.1.0
    OPERATIONS_TOKEN=replace-with-rotatable-24-plus-character-token
  '';

  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.nodejs_22
    pkgs.openssh
    pkgs.bun
    pkgs.gzip
    pkgs.podman
    pkgs.postgresql_16
    pkgs.systemd
  ];

  buildScript = pkgs.writeShellScript "unprompted-build" ''
    set -euo pipefail

    export PATH=${runtimePath}:$PATH
    export HOME=/var/lib/unprompted
    export CI=true
    export NEXT_TELEMETRY_DISABLED=1
    export GIT_SSH_COMMAND="ssh -i ${config.sops.secrets.unprompted_deploy_key.path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/unprompted/github-known-hosts"

    if [ ! -f ${lib.escapeShellArg runtimeEnvFile} ]; then
      echo "Missing rendered Unprompted production environment." >&2
      exit 1
    fi

    if [ ! -d ${lib.escapeShellArg repoDir}/.git ]; then
      rm -rf ${lib.escapeShellArg repoDir}
      git clone --branch ${lib.escapeShellArg cfg.branch} ${lib.escapeShellArg cfg.repository} ${lib.escapeShellArg repoDir}
    fi

    cd ${lib.escapeShellArg repoDir}
    git fetch origin ${lib.escapeShellArg cfg.branch}
    git reset --hard origin/${lib.escapeShellArg cfg.branch}

    node ops/scripts/staging-preflight.mjs -- \
      --env-file ${lib.escapeShellArg runtimeEnvFile} \
      --allow-local-database
    bun install --frozen-lockfile

    for attempt in $(seq 1 60); do
      if pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        pg_isready -d "$DATABASE_URL"
      fi
      sleep 2
    done

    podman exec -i -u postgres unprompted-postgres \
      psql -U unprompted -d unprompted -v ON_ERROR_STOP=1 <<'SQL'
    \getenv configured_password POSTGRES_PASSWORD
    ALTER ROLE unprompted PASSWORD :'configured_password';
    SQL

    bun run build
    mkdir -p apps/web/.next/standalone/apps/web/.next/static
    cp -a apps/web/.next/static/. apps/web/.next/standalone/apps/web/.next/static/
    if ! find apps/web/.next/standalone/apps/web/.next/static -type f -name '*.css' -print -quit | grep -q .; then
      echo "Unprompted standalone runtime is missing its CSS assets." >&2
      exit 1
    fi
    bun run db:migrate

    rm -rf ${lib.escapeShellArg runtimeDir}
    rm -rf node_modules apps/*/node_modules packages/*/node_modules
    bun install --frozen-lockfile --production --filter @unprompted/api
    node ops/scripts/assemble-bun-runtime.mjs ${lib.escapeShellArg "${runtimeDir}/api"}
    mkdir -p ${lib.escapeShellArg "${runtimeDir}/api/apps/api"}
    cp -a apps/api/dist ${lib.escapeShellArg "${runtimeDir}/api/apps/api/dist"}

    rm -rf node_modules apps/*/node_modules packages/*/node_modules
    bun install --frozen-lockfile --production --filter @unprompted/worker
    node ops/scripts/assemble-bun-runtime.mjs ${lib.escapeShellArg "${runtimeDir}/worker"}
    mkdir -p ${lib.escapeShellArg "${runtimeDir}/worker/apps/worker"}
    cp -a apps/worker/dist ${lib.escapeShellArg "${runtimeDir}/worker/apps/worker/dist"}
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

    repository = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:rodrgds/unprompted.git";
      description = "Git repository cloned on the VPS for source builds.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch deployed by the source-build service.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3210;
      description = "Local port for the Next.js web service.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 4100;
      description = "Local port for the Hono API service.";
    };

    postgresPort = lib.mkOption {
      type = lib.types.port;
      default = 5442;
      description = "Local PostgreSQL port exposed by the Unprompted Postgres container.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."unprompted/production.env.example".text = envExample;
    environment.etc."unprompted/github-known-hosts".text = ''
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';

    sops.templates."unprompted-production-env" = {
      content = ''
        NODE_ENV=production
        PORT=${toString cfg.apiPort}
        API_ORIGIN=http://127.0.0.1:${toString cfg.apiPort}
        API_URL=https://${cfg.apiDomain}
        NEXT_PUBLIC_API_URL=https://${cfg.apiDomain}
        EXPO_PUBLIC_API_URL=https://${cfg.apiDomain}

        POSTGRES_USER=unprompted
        POSTGRES_DB=unprompted
        POSTGRES_PASSWORD=${config.sops.placeholder.unprompted_postgres_password}
        DATABASE_URL=postgres://unprompted:${config.sops.placeholder.unprompted_postgres_password}@127.0.0.1:${toString cfg.postgresPort}/unprompted

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

        RESEND_API_KEY=${config.sops.placeholder.unprompted_resend_api_key}
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
        "podman-unprompted-postgres.service"
        "unprompted-build.service"
        "unprompted-api.service"
        "unprompted-worker.service"
        "unprompted-web.service"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/unprompted 0750 root root -"
      "d /var/lib/unprompted/postgres 0700 70 70 -"
      "d /var/lib/unprompted/repo 0750 root root -"
      "d /var/backup/unprompted 0750 root root -"
    ];

    virtualisation.oci-containers.containers.unprompted-postgres = {
      image = "docker.io/postgres:17-alpine";

      environment = {
        POSTGRES_USER = "unprompted";
        POSTGRES_DB = "unprompted";
      };

      environmentFiles = [ runtimeEnvFile ];

      volumes = [
        "/var/lib/unprompted/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString cfg.postgresPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=pg_isready -U unprompted -d unprompted"
        "--health-interval=10s"
        "--health-timeout=5s"
        "--health-retries=12"
      ];
    };

    systemd.services.podman-unprompted-postgres.unitConfig.ConditionPathExists = runtimeEnvFile;

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

    systemd.services.unprompted-build = {
      description = "Build and migrate Unprompted from source";
      after = [
        "network-online.target"
        "podman-unprompted-postgres.service"
      ];
      wants = [
        "network-online.target"
        "podman-unprompted-postgres.service"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = runtimeEnvFile;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/var/lib/unprompted";
        EnvironmentFile = runtimeEnvFile;
        ExecStart = buildScript;
        ExecStartPost = "${pkgs.systemd}/bin/systemctl try-restart unprompted-api.service unprompted-worker.service unprompted-web.service";
        TimeoutStartSec = "45min";
      };
    };

    systemd.services.unprompted-api = {
      description = "Unprompted API";
      after = [
        "unprompted-build.service"
        "podman-unprompted-postgres.service"
      ];
      requires = [
        "unprompted-build.service"
        "podman-unprompted-postgres.service"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "${runtimeDir}/api/apps/api/dist/server.js";

      serviceConfig = {
        WorkingDirectory = "${runtimeDir}/api";
        EnvironmentFile = runtimeEnvFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.apiPort}"
        ];
        ExecStart = "${pkgs.coreutils}/bin/env PORT=${toString cfg.apiPort} ${pkgs.nodejs_22}/bin/node apps/api/dist/server.js";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
      };
    };

    systemd.services.unprompted-worker = {
      description = "Unprompted worker";
      after = [
        "unprompted-build.service"
        "podman-unprompted-postgres.service"
      ];
      requires = [
        "unprompted-build.service"
        "podman-unprompted-postgres.service"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "${runtimeDir}/worker/apps/worker/dist/index.js";

      serviceConfig = {
        WorkingDirectory = "${runtimeDir}/worker";
        EnvironmentFile = runtimeEnvFile;
        Environment = [
          "NODE_ENV=production"
          "API_ORIGIN=http://127.0.0.1:${toString cfg.apiPort}"
        ];
        ExecStart = "${pkgs.nodejs_22}/bin/node apps/worker/dist/index.js";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
      };
    };

    systemd.services.unprompted-web = {
      description = "Unprompted web";
      after = [ "unprompted-build.service" ];
      requires = [ "unprompted-build.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "${repoDir}/apps/web/.next/standalone/apps/web/server.js";

      serviceConfig = {
        WorkingDirectory = "${repoDir}/apps/web/.next/standalone";
        EnvironmentFile = runtimeEnvFile;
        Environment = [
          "NODE_ENV=production"
          "NEXT_TELEMETRY_DISABLED=1"
          "HOSTNAME=127.0.0.1"
          "PORT=${toString cfg.webPort}"
        ];
        ExecStart = "${pkgs.coreutils}/bin/env PORT=${toString cfg.webPort} ${pkgs.nodejs_22}/bin/node apps/web/server.js";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.domain}" = {
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
        extraConfig = ''
          redir https://${cfg.domain}{uri} permanent
        '';
      };

      "${cfg.apiDomain}" = {
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
