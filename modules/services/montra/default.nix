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

  # Podman runs the first check immediately; keep the transient systemd unit
  # active while the service boots so a restart does not briefly fail the
  # NixOS switch (montra-api uses the same pattern with a bun one-liner).
  pythonHealthCheck =
    url:
    "--health-cmd=python -c \"import urllib.request,time\nfor i in range(60):\n    try:\n        urllib.request.urlopen('${url}')\n        exit(0)\n    except Exception:\n        time.sleep(1)\nexit(1)\"";
  stopManagedContainer =
    name:
    pkgs.writeShellScript "stop-${name}" ''
      set -euo pipefail
      if ${pkgs.podman}/bin/podman container exists ${lib.escapeShellArg name}; then
        # Podman 5.8 leaves container-ID-specific health timers behind after a
        # replacement unless both the timer and any active probe are stopped.
        ${pkgs.podman}/bin/podman update --health-interval=disable ${lib.escapeShellArg name} >/dev/null
        container_id="$(${pkgs.coreutils}/bin/cat /run/${name}/ctr-id)"
        [[ "$container_id" =~ ^[0-9a-f]{64}$ ]] || {
          echo "invalid ${name} container ID" >&2
          exit 1
        }
        for unit_type in timer service; do
          while read -r unit _; do
            [ -n "$unit" ] || continue
            ${pkgs.systemd}/bin/systemctl stop "$unit" || true
            if [ "$unit_type" = service ]; then
              ${pkgs.systemd}/bin/systemctl reset-failed "$unit" || true
            fi
          done < <(
            ${pkgs.systemd}/bin/systemctl list-units \
              --all --plain --no-legend "$container_id-*.$unit_type"
          )
        done
      fi
      ${pkgs.podman}/bin/podman stop --ignore --cidfile=/run/${name}/ctr-id
    '';
  montraMaintenance = pkgs.writeShellScriptBin "montra-catalog-maintenance" ''
    set -euo pipefail
    [ "$#" -gt 0 ] || {
      echo "usage: montra-catalog-maintenance <command> [args...]" >&2
      exit 64
    }
    exec ${pkgs.util-linux}/bin/flock --exclusive /run/montra-catalog-maintenance.lock \
      ${pkgs.util-linux}/bin/flock --exclusive /run/podman-maintenance.lock "$@"
  '';
  initializeScript = pkgs.writeShellScript "montra-initialize" ''
    set -euo pipefail
    until ${pkgs.podman}/bin/podman exec montra-postgres pg_isready -U ${postgresUser} -d ${postgresDatabase}; do sleep 2; done
    # The existing production image predates /health/ready. Keep the boot-time
    # transition probe shallow; candidate deploy verification below requires
    # the new model-loading readiness endpoint before reporting success.
    until ${pkgs.podman}/bin/podman exec montra-embedding python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8811/health')"; do sleep 2; done
    until ${pkgs.podman}/bin/podman exec montra-detector python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8812/health/ready')"; do sleep 2; done
    if [ -f /var/lib/montra/bootstrap/montra.dump ] && ! ${pkgs.podman}/bin/podman exec montra-postgres psql -U ${postgresUser} -d ${postgresDatabase} -Atqc "select to_regclass('public.product') is not null" | ${pkgs.gnugrep}/bin/grep -qx t; then
      ${pkgs.podman}/bin/podman exec -i montra-postgres pg_restore -U ${postgresUser} -d ${postgresDatabase} --no-owner --no-acl < /var/lib/montra/bootstrap/montra.dump
      touch /var/lib/montra/bootstrap/.needs-search-index
    fi
    api_image_id="$(${pkgs.podman}/bin/podman image inspect ${apiImage} --format '{{.Id}}')"
    [[ "$api_image_id" =~ ^(sha256:)?[0-9a-f]{64}$ ]] || {
      echo "verified local Montra API image is unavailable" >&2
      exit 1
    }
    run_api=(
      ${pkgs.podman}/bin/podman run --rm --pull=never --network=podman
      --env-file=${config.sops.templates.montra-env.path} "$api_image_id"
    )
    "''${run_api[@]}" bun run db:migrate
    "''${run_api[@]}" bun run configure:search
    if [ -f /var/lib/montra/bootstrap/.needs-search-index ]; then
      "''${run_api[@]}" bun run index:search:incremental
      rm -f /var/lib/montra/bootstrap/.needs-search-index
    fi
  '';
  montraComponents = [
    "api"
    "web"
    "embedding"
    "detector"
    "postgres"
  ];
in
{
  options.vps.montra = {
    enable = lib.mkEnableOption "Enable Montra";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "montra.style";
    };
    bootstrapImages = lib.genAttrs montraComponents (
      component:
      lib.mkOption {
        type = lib.types.submodule {
          options = {
            digest = lib.mkOption { type = lib.types.strMatching "^sha256:[0-9a-f]{64}$"; };
            revision = lib.mkOption { type = lib.types.strMatching "^[0-9a-f]{40}$"; };
          };
        };
        description = "Verified ${component} image used only when the local Montra tag is absent.";
      }
    );
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [
      "montra_postgres_password"
      "montra_better_auth_secret"
      "montra_admin_emails"
      "montra_google_client_id"
      "montra_google_client_secret"
      "montra_discord_search_webhook_url"
      "montra_discord_signup_webhook_url"
      "montra_openrouter_api_key"
      "montra_meili_master_key"
      "montra_r2_access_key_id"
      "montra_r2_secret_access_key"
      "montra_r2_artifact_access_key_id"
      "montra_r2_artifact_secret_access_key"
    ] (_: { });

    systemd.tmpfiles.rules = [
      "d /var/lib/montra 0750 root root -"
      "d /var/lib/montra/deploy-deliveries 0700 root root 30d"
      "d /var/lib/montra/postgres 0700 70 70 -"
      "d /var/lib/montra/meilisearch 0750 1000 1000 -"
      "d /var/lib/montra/bootstrap 0750 root root -"
      "d /var/lib/montra/backup-status 0755 root root -"
      "z /var/lib/montra/backup-status/status.json 0644 root root -"
      "d /var/backup/montra 0750 root root -"
      "f /run/montra-catalog-maintenance.lock 0666 root root -"
    ];

    environment.systemPackages = [ montraMaintenance ];

    sops.templates = {
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
          API_RATE_LIMIT_ENABLED=true
          ADMIN_EMAILS=${config.sops.placeholder.montra_admin_emails}
          GOOGLE_CLIENT_ID=${config.sops.placeholder.montra_google_client_id}
          GOOGLE_CLIENT_SECRET=${config.sops.placeholder.montra_google_client_secret}
          DISCORD_SEARCH_WEBHOOK_URL=${config.sops.placeholder.montra_discord_search_webhook_url}
          DISCORD_SIGNUP_WEBHOOK_URL=${config.sops.placeholder.montra_discord_signup_webhook_url}
          AI_PROVIDER=openrouter
          OPENROUTER_API_KEY=${config.sops.placeholder.montra_openrouter_api_key}
          OPENROUTER_QUERY_MODEL=google/gemini-2.5-flash-lite
          OPENROUTER_VISION_MODEL=google/gemini-2.5-flash-lite
          SEARCH_PROVIDER=meilisearch
          CATALOG_PREWARM=1
          ADMIN_EMBEDDED_JOB_WORKER=0
          CATALOG_MAINTENANCE_LOCK_FILE=/run/montra-catalog-maintenance.lock
          CATALOG_MAINTENANCE_SOURCE_IDS=isto,salsa,tiffosi,sacoor,calzedonia,bimbaylola,prof,bershka,stradivarius,jdsports,lefties,seaside
          CATALOG_WORKER_TOKEN_SHA256=aacc46672cbb244bf6d106d051ba01bf81ebb7e335c427b3b16c57352cc3177d
          MEILI_HOST=http://montra-meilisearch:7700
          MEILI_MASTER_KEY=${config.sops.placeholder.montra_meili_master_key}
          VISUAL_SEARCH_PROVIDER=external
          VISUAL_INDEX_BACKEND=postgres
          VISUAL_EMBEDDING_URL=http://montra-embedding:8811/embed-image
          VISUAL_EMBEDDING_MODEL=openai/clip-vit-base-patch32
          VISUAL_APPEARANCE_PUBLIC_IMAGE_BASE_URL=http://127.0.0.1:9000/fashion-radar
          VISUAL_APPEARANCE_INTERNAL_IMAGE_BASE_URL=https://media.${cfg.domain}
          IMAGE_ITEM_DETECTOR=yolo-world
          FASHION_DETECTOR_URL=http://montra-detector:8812/detect
          FASHION_DETECTOR_MODEL=/app/models/yolov8s-worldv2.pt
          FASHION_DETECTOR_REQUIRE_EXTERNAL=1
          FASHION_DETECTOR_TIMEOUT_MS=8000
          PINTEREST_IMPORT_MODE=off
          OBJECT_STORAGE_PROVIDER=r2
          OBJECT_STORAGE_ENDPOINT=https://1e84f0262ece6e76da6df50801960036.r2.cloudflarestorage.com
          OBJECT_STORAGE_REGION=auto
          OBJECT_STORAGE_BUCKET=montra
          OBJECT_STORAGE_ACCESS_KEY=${config.sops.placeholder.montra_r2_access_key_id}
          OBJECT_STORAGE_SECRET_KEY=${config.sops.placeholder.montra_r2_secret_access_key}
          OBJECT_STORAGE_PUBLIC_URL=https://media.${cfg.domain}
          # Catalog operations console identity. The fingerprint is derived
          # from this pair, so changing either invalidates in-flight reviews.
          CATALOG_TARGET_ID=montra-production
          CATALOG_ENVIRONMENT=production
          CATALOG_CONSOLE_CLIENT_ID=montra-catalog-console
          ADMIN_CONSOLE_ORIGINS=https://${cfg.domain}
          # Verified-backup gate. The daily backup job writes status.json after
          # gzip verification; catalog mutations block while it goes stale.
          CATALOG_BACKUP_STATUS_FILE=/var/lib/montra/backup-status/status.json
          CATALOG_BACKUP_MAX_AGE_HOURS=24
          # Private write-once artifact bucket for source runs. Never exposed
          # on a public domain; imports reference keys plus their SHA-256.
          CATALOG_ARTIFACT_STORAGE_PROVIDER=r2
          CATALOG_ARTIFACT_STORAGE_ENDPOINT=https://1e84f0262ece6e76da6df50801960036.r2.cloudflarestorage.com
          CATALOG_ARTIFACT_STORAGE_REGION=auto
          CATALOG_ARTIFACT_STORAGE_BUCKET=montra-artifacts
          CATALOG_ARTIFACT_STORAGE_ACCESS_KEY_ID=${config.sops.placeholder.montra_r2_artifact_access_key_id}
          CATALOG_ARTIFACT_STORAGE_SECRET_ACCESS_KEY=${config.sops.placeholder.montra_r2_artifact_secret_access_key}
          CATALOG_ARTIFACT_STORAGE_FORCE_PATH_STYLE=false
          # Production visual search is stored in Postgres. Do not also write a
          # local index into the read-only application image.
          VISUAL_WRITE_INDEX_FILE=0
          # Schedules ship disabled by default on purpose; enabling automated
          # runs is an explicit later operator decision.
        '';
        mode = "0400";
        restartUnits = [
          "podman-montra-api.service"
          "podman-montra-worker.service"
          "podman-montra-integration-worker.service"
        ];
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

    systemd.services.podman-montra-postgres = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
      serviceConfig.ExecStop = lib.mkForce "${stopManagedContainer "montra-postgres"}";
    };
    systemd.services.podman-montra-meilisearch = {
      serviceConfig.ExecStop = lib.mkForce "${stopManagedContainer "montra-meilisearch"}";
    };
    systemd.services.podman-montra-embedding = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
      serviceConfig.ExecStop = lib.mkForce "${stopManagedContainer "montra-embedding"}";
    };
    systemd.services.podman-montra-detector = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
      serviceConfig.ExecStop = lib.mkForce "${stopManagedContainer "montra-detector"}";
    };
    systemd.services.podman-montra-api = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
      serviceConfig.ExecStop = lib.mkForce "${stopManagedContainer "montra-api"}";
    };
    systemd.services.podman-montra-worker = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
    };
    systemd.services.podman-montra-integration-worker = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
    };
    systemd.services.podman-montra-web = {
      after = [ "packages-registry-login.service" ];
      requires = [ "packages-registry-login.service" ];
    };

    systemd.services.montra-images = {
      description = "Seed and verify local Montra production images";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [
        "montra-initialize.service"
        "podman-montra-postgres.service"
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
        "podman-montra-api.service"
        "podman-montra-worker.service"
        "podman-montra-integration-worker.service"
        "podman-montra-web.service"
      ];
      requiredBy = [
        "montra-initialize.service"
        "podman-montra-postgres.service"
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
        "podman-montra-api.service"
        "podman-montra-worker.service"
        "podman-montra-integration-worker.service"
        "podman-montra-web.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # A disaster-recovery bootstrap may need to pull all five production
        # images, including the larger model services, into an empty store.
        # Let registry/network timeouts fail the individual pull rather than
        # allowing systemd's default unit timeout to kill a healthy transfer.
        TimeoutStartSec = "infinity";
        ExecStart = pkgs.writeShellScript "montra-images" ''
          set -euo pipefail
          exec 9>/run/podman-maintenance.lock
          ${pkgs.util-linux}/bin/flock --exclusive 9
          components=(
            "api|ghcr.io/rodrgds/montra-api|${cfg.bootstrapImages.api.digest}|${cfg.bootstrapImages.api.revision}"
            "web|ghcr.io/rodrgds/montra-web|${cfg.bootstrapImages.web.digest}|${cfg.bootstrapImages.web.revision}"
            "embedding|ghcr.io/rodrgds/montra-embedding|${cfg.bootstrapImages.embedding.digest}|${cfg.bootstrapImages.embedding.revision}"
            "detector|ghcr.io/rodrgds/montra-detector|${cfg.bootstrapImages.detector.digest}|${cfg.bootstrapImages.detector.revision}"
            "postgres|ghcr.io/rodrgds/montra-postgres|${cfg.bootstrapImages.postgres.digest}|${cfg.bootstrapImages.postgres.revision}"
          )

          for entry in "''${components[@]}"; do
            IFS='|' read -r component image digest revision <<< "$entry"
            if ! ${pkgs.podman}/bin/podman image exists "$image:latest"; then
              ${pkgs.systemd}/bin/systemctl restart packages-registry-login.service
              ${pkgs.podman}/bin/podman pull "$image@$digest"
              image_revision="$(${pkgs.podman}/bin/podman image inspect "$image@$digest" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
              [ "$image_revision" = "$revision" ] || {
                echo "$component bootstrap revision $image_revision does not match $revision" >&2
                exit 1
              }
              ${pkgs.podman}/bin/podman tag "$image@$digest" "$image:latest"
              seeded_image="$(${pkgs.podman}/bin/podman image inspect "$image@$digest" --format '{{.Id}}')"
              tagged_image="$(${pkgs.podman}/bin/podman image inspect "$image:latest" --format '{{.Id}}')"
              [ "$tagged_image" = "$seeded_image" ] || {
                echo "$component bootstrap tag does not reference the verified digest" >&2
                exit 1
              }
            fi
            image_id="$(${pkgs.podman}/bin/podman image inspect "$image:latest" --format '{{.Id}}')"
            [[ "$image_id" =~ ^(sha256:)?[0-9a-f]{64}$ ]] || {
              echo "$component local image has an invalid ID" >&2
              exit 1
            }
            image_revision="$(${pkgs.podman}/bin/podman image inspect "$image:latest" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
            [[ "$image_revision" =~ ^[0-9a-f]{40}$ ]] || {
              echo "$component local image has an invalid revision label" >&2
              exit 1
            }
          done
        '';
      };
    };

    virtualisation.oci-containers.containers = {
      montra-postgres = {
        image = "ghcr.io/rodrgds/montra-postgres:latest";
        environmentFiles = [ config.sops.templates.montra-postgres-env.path ];
        volumes = [ "/var/lib/montra/postgres:/var/lib/postgresql/data" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
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
        environment = {
          FASHION_APPEARANCE_INTERNAL_ORIGINS = "https://media.${cfg.domain}";
        };
        extraOptions = [
          "--network=podman"
          "--pull=never"
          (pythonHealthCheck "http://127.0.0.1:8811/health")
          "--health-interval=30s"
          "--health-timeout=65s"
          "--health-retries=10"
          "--memory=3g"
        ];
      };
      montra-detector = {
        image = "ghcr.io/rodrgds/montra-detector:latest";
        extraOptions = [
          "--network=podman"
          "--pull=never"
          (pythonHealthCheck "http://127.0.0.1:8812/health/ready")
          "--health-interval=30s"
          "--health-timeout=65s"
          "--health-retries=10"
          "--memory=2g"
        ];
      };
      montra-api = {
        image = apiImage;
        environmentFiles = [ config.sops.templates.montra-env.path ];
        ports = [ "127.0.0.1:${toString apiPort}:8787" ];
        volumes = [
          "/run/montra-catalog-maintenance.lock:/run/montra-catalog-maintenance.lock"
          "/var/lib/montra/backup-status:/var/lib/montra/backup-status:ro"
        ];
        dependsOn = [
          "montra-postgres"
          "montra-meilisearch"
          "montra-embedding"
          "montra-detector"
        ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          # Podman runs the first check immediately. Keep that transient
          # systemd unit active while the API boots instead of briefly
          # failing the entire NixOS switch before Bun starts listening.
          "--health-cmd=bun -e \"for(let i=0;i<25;i++){try{const r=await fetch('http://127.0.0.1:8787/health/ready');if(r.ok)process.exit(0)}catch{}await new Promise(r=>setTimeout(r,1000))}process.exit(1)\""
          "--health-interval=15s"
          "--health-timeout=30s"
          "--health-retries=12"
          "--memory=4g"
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
        volumes = [
          "/run/montra-catalog-maintenance.lock:/run/montra-catalog-maintenance.lock"
          "/var/lib/montra/backup-status:/var/lib/montra/backup-status:ro"
        ];
        dependsOn = [
          "montra-postgres"
          "montra-meilisearch"
          "montra-embedding"
          "montra-detector"
        ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          # A fresh catalog snapshot expands roughly 500 MiB of JSON into
          # JavaScript objects before derived processing starts.
          "--memory=3g"
        ];
      };
      montra-integration-worker = {
        image = apiImage;
        cmd = [
          "bun"
          "run"
          "integration:worker"
        ];
        environmentFiles = [ config.sops.templates.montra-env.path ];
        dependsOn = [ "montra-postgres" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          "--memory=512m"
        ];
      };
      montra-web = {
        image = "ghcr.io/rodrgds/montra-web:latest";
        ports = [ "127.0.0.1:${toString webPort}:3000" ];
        dependsOn = [ "montra-api" ];
        extraOptions = [
          "--network=podman"
          "--pull=never"
          "--memory=512m"
        ];
      };
    };

    systemd.services.montra-initialize = {
      description = "Restore, migrate, and index the Montra catalog";
      after = [
        "podman-montra-postgres.service"
        "podman-montra-meilisearch.service"
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
        "packages-registry-login.service"
      ];
      requires = [
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
      ];
      before = [
        "podman-montra-api.service"
        "podman-montra-worker.service"
        "podman-montra-integration-worker.service"
      ];
      requiredBy = [
        "podman-montra-api.service"
        "podman-montra-worker.service"
        "podman-montra-integration-worker.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "infinity";
        # Deploys already hold the shared catalog and Podman locks while this
        # required boot initializer is started as an API dependency. Taking
        # the Podman lock again here would deadlock the same deployment.
        ExecStart = initializeScript;
      };
    };

    systemd.services.montra-deploy-initialize = {
      description = "Migrate and configure Montra before replacing API containers";
      # The parent deploy owns both maintenance locks and has already promoted
      # the verified API candidate. A dependency on the boot initializer would
      # try to acquire the same lock again.
      after = [
        "podman-montra-postgres.service"
        "podman-montra-meilisearch.service"
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
      ];
      requires = [
        "podman-montra-postgres.service"
        "podman-montra-embedding.service"
        "podman-montra-detector.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "infinity";
        ExecStart = initializeScript;
      };
    };

    systemd.services.montra-postgres-backup = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "montra-postgres-backup" ''
          set -euo pipefail
          umask 0077
          stamp=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          backup_dir=/var/backup/montra
          backup="$backup_dir/montra_$stamp.sql.gz"
          partial="$backup.partial"
          trap '${pkgs.coreutils}/bin/rm -f "$partial"' EXIT

          ${pkgs.podman}/bin/podman exec montra-postgres pg_dump \
            -U ${postgresUser} -d ${postgresDatabase} | ${pkgs.gzip}/bin/gzip > "$partial"
          ${pkgs.gzip}/bin/gzip -t "$partial"
          ${pkgs.coreutils}/bin/mv "$partial" "$backup"
          trap - EXIT

          # The catalog console refuses mutations while this status file goes
          # stale, so it must only exist after a verified recovery point.
          ${pkgs.coreutils}/bin/printf '{"verifiedAt":"%s","checksum":"%s","label":"%s"}\n' \
            "$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" \
            "$(${pkgs.coreutils}/bin/sha256sum "$backup" | ${pkgs.coreutils}/bin/cut -d' ' -f1)" \
            "$(${pkgs.coreutils}/bin/basename "$backup")" \
            > /var/lib/montra/backup-status/status.json.tmp
          ${pkgs.coreutils}/bin/chmod 0644 \
            /var/lib/montra/backup-status/status.json.tmp
          ${pkgs.coreutils}/bin/mv /var/lib/montra/backup-status/status.json.tmp \
            /var/lib/montra/backup-status/status.json

          # Full dumps are roughly 2 GiB each on this host. Keep exactly the
          # two newest verified recovery points instead of accumulating by age.
          ${pkgs.findutils}/bin/find "$backup_dir" -maxdepth 1 -type f \
            -name 'montra_*.sql.gz' -printf '%T@ %p\0' \
            | ${pkgs.coreutils}/bin/sort -z -nr \
            | ${pkgs.coreutils}/bin/tail -z -n +3 \
            | ${pkgs.coreutils}/bin/cut -z -d ' ' -f 2- \
            | ${pkgs.findutils}/bin/xargs -0r ${pkgs.coreutils}/bin/rm -f --
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

    services.caddy.virtualHosts.${cfg.domain} = {
      logFormat = config.vps.caddy.accessLogFor cfg.domain;
      extraConfig = ''
        encode zstd gzip
        header {
          -Server
          Content-Security-Policy "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; script-src 'self' 'unsafe-inline' https://cool.rgo.pt; connect-src 'self' https://cool.rgo.pt; img-src 'self' data: blob: https:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; worker-src 'self' blob:"
          Strict-Transport-Security "max-age=31536000; includeSubDomains"
          X-Content-Type-Options "nosniff"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
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
  };
}
