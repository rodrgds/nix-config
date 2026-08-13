{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.hosting.deployments;
  maintenancePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.curl
    pkgs.git
    pkgs.jq
    pkgs.gnugrep
    pkgs.podman
    pkgs.systemd
    pkgs.util-linux
  ];

  pruneImages = ''
    podman image prune --force --build-cache
  '';

  personalWebsiteDeploy = pkgs.writeShellScript "deploy-personal-website" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    systemctl restart personal-site.service
    systemctl restart personal-site-run.service

    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:4321/ >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u personal-site.service -u personal-site-run.service -n 160 --no-pager >&2
        exit 1
      fi
      sleep 2
    done

    curl -fsS https://rgo.pt/ >/dev/null
  '';

  openpostDeploy = pkgs.writeShellScript "deploy-openpost" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    revision="''${1:-}"
    release_tag="''${2:-}"
    digest="''${3:-}"
    image_name=ghcr.io/getopenpost/openpost

    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "invalid OpenPost revision" >&2; exit 1; }
    [[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid OpenPost release tag" >&2; exit 1; }
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "invalid OpenPost image digest" >&2; exit 1; }

    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    candidate="$image_name@$digest"
    previous_image="$(podman image inspect "$image_name:latest" --format '{{.Id}}')"
    podman tag "$previous_image" "$image_name:rollback"
    podman pull "$candidate"

    image_revision="$(podman image inspect "$candidate" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
    [ "$image_revision" = "$revision" ] || {
      echo "candidate image revision $image_revision does not match $revision" >&2
      exit 1
    }

    # Validate the candidate against the exact production environment and
    # mounted *_FILE secrets without opening a port or touching the database.
    candidate_args=(--rm --network none)
    while IFS= read -r environment; do
      environment_key="''${environment%%=*}"
      environment_is_managed=false
      while IFS='=' read -r configured_key _; do
        if [ "$configured_key" = "$environment_key" ]; then
          environment_is_managed=true
          break
        fi
      done < ${config.sops.templates.openpost-cloud-env.path}
      if $environment_is_managed; then
        continue
      fi
      candidate_args+=(--env "$environment")
    done < <(podman inspect openpost | jq -r '.[0].Config.Env[]')
    candidate_args+=(--env-file ${config.sops.templates.openpost-cloud-env.path})
    while IFS=$'\t' read -r source destination; do
      candidate_args+=(--volume "$source:$destination:ro")
    done < <(podman inspect openpost | jq -r '.[0].Mounts[] | select(.Type == "bind") | [.Source, .Destination] | @tsv')
    podman run "''${candidate_args[@]}" "$candidate" ./openpost check-config

    podman tag "$candidate" "$image_name:latest"
    if ! systemctl restart podman-openpost.service; then
      podman tag "$image_name:rollback" "$image_name:latest"
      systemctl restart podman-openpost.service
      exit 1
    fi

    for attempt in $(seq 1 60); do
      running_revision="$(curl -fsS http://127.0.0.1:8090/api/v1/version 2>/dev/null | jq -r .revision 2>/dev/null || true)"
      if [ "$running_revision" = "$revision" ] && curl -fsS http://127.0.0.1:8090/api/v1/ready >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u podman-openpost.service -n 120 --no-pager >&2
        podman tag "$image_name:rollback" "$image_name:latest"
        systemctl restart podman-openpost.service
        for rollback_attempt in $(seq 1 30); do
          curl -fsS http://127.0.0.1:8090/api/v1/ready >/dev/null && break
          sleep 2
        done
        exit 1
      fi
      sleep 2
    done

    if ! curl -fsS https://app.openpost.social/api/v1/ready >/dev/null; then
      podman tag "$image_name:rollback" "$image_name:latest"
      systemctl restart podman-openpost.service
      exit 1
    fi
    public_revision="$(curl -fsS https://app.openpost.social/api/v1/version | jq -r .revision)"
    if [ "$public_revision" != "$revision" ]; then
      podman tag "$image_name:rollback" "$image_name:latest"
      systemctl restart podman-openpost.service
      echo "public OpenPost revision $public_revision does not match $revision" >&2
      exit 1
    fi
    ${pruneImages}
    echo "DEPLOY_OK openpost $revision $release_tag"
  '';

  triggerOpenpostDeploy = pkgs.writeShellScript "trigger-deploy-openpost" ''
    set -euo pipefail
    exec ${openpostDeploy} "$@"
  '';

  montraDeploy = pkgs.writeShellScript "deploy-montra" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    [ "$#" -eq 2 ] || { echo "expected Montra revision and component digest map" >&2; exit 1; }
    revision="$1"
    components_json="$2"
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "invalid Montra revision" >&2; exit 1; }
    jq -e -f ${./montra-payload-components.jq} <<< "$components_json" >/dev/null || {
      echo "invalid Montra component digest map" >&2
      exit 1
    }

    # The admin worker and manual maintenance wrapper hold this first lock for
    # the full catalog mutation. Consistent ordering prevents deploy/job races.
    exec 8>/run/montra-catalog-maintenance.lock
    flock --exclusive 8
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    all_components=(postgres embedding detector api web)
    selected_components=()
    declare -A candidate_images=()
    declare -A digests=()
    declare -A previous_images=()

    component_selected() {
      jq -e --arg component "$1" 'has($component)' <<< "$components_json" >/dev/null
    }

    image_name() {
      printf 'ghcr.io/rodrgds/montra-%s' "$1"
    }

    for component in "''${all_components[@]}"; do
      if ! component_selected "$component"; then
        continue
      fi
      selected_components+=("$component")
      image="$(image_name "$component")"
      digest="$(jq -er --arg component "$component" '.[$component]' <<< "$components_json")"
      previous_image="$(podman image inspect "$image:latest" --format '{{.Id}}')" || {
        echo "missing previous Montra $component image; refusing promotion without rollback" >&2
        exit 1
      }
      [[ "$previous_image" =~ ^(sha256:)?[0-9a-f]{64}$ ]] || {
        echo "previous Montra $component image has an invalid ID" >&2
        exit 1
      }
      previous_images[$component]="$previous_image"
      previous_revision="$(podman image inspect "$previous_image" --format '{{index .Labels "org.opencontainers.image.revision"}}')" || {
        echo "previous Montra $component image has no inspectable revision" >&2
        exit 1
      }
      [[ "$previous_revision" =~ ^[0-9a-f]{40}$ ]] || {
        echo "previous Montra $component image has an invalid revision label" >&2
        exit 1
      }
      running_containers=()
      case "$component" in
        api) running_containers=(montra-api montra-worker montra-integration-worker) ;;
        *) running_containers=("montra-$component") ;;
      esac
      for container in "''${running_containers[@]}"; do
        running_image_name="$(podman inspect "$container" --format '{{.ImageName}}')" || {
          echo "cannot inspect running Montra container $container" >&2
          exit 1
        }
        running_image="$(podman image inspect "$running_image_name" --format '{{.Id}}')" || {
          echo "cannot inspect running Montra image $running_image_name" >&2
          exit 1
        }
        [ "$running_image" = "$previous_image" ] || {
          echo "$container runs $running_image, but $image:latest is $previous_image; refusing an unverifiable rollback" >&2
          exit 1
        }
      done
      digests[$component]="$digest"
    done

    systemctl restart packages-registry-login.service
    for component in "''${selected_components[@]}"; do
      image="$(image_name "$component")"
      candidate="$image@''${digests[$component]}"
      podman pull "$candidate"
      image_revision="$(podman image inspect "$candidate" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
      [ "$image_revision" = "$revision" ] || {
        echo "$component candidate revision $image_revision does not match $revision" >&2
        exit 1
      }
      candidate_image="$(podman image inspect "$candidate" --format '{{.Id}}')"
      [[ "$candidate_image" =~ ^(sha256:)?[0-9a-f]{64}$ ]] || {
        echo "$component candidate image has an invalid ID" >&2
        exit 1
      }
      candidate_images[$component]="$candidate_image"
      podman tag "''${previous_images[$component]}" "$image:rollback"
    done

    restore_previous_tags() {
      for component in "''${selected_components[@]}"; do
        image="$(image_name "$component")"
        podman tag "''${previous_images[$component]}" "$image:latest" || return 1
        restored_image="$(podman image inspect "$image:latest" --format '{{.Id}}')" || return 1
        [ "$restored_image" = "''${previous_images[$component]}" ] || return 1
      done
    }

    promote_candidates() {
      for component in "''${selected_components[@]}"; do
        image="$(image_name "$component")"
        podman tag "$image@''${digests[$component]}" "$image:latest" || return 1
        promoted_image="$(podman image inspect "$image:latest" --format '{{.Id}}')" || return 1
        [ "$promoted_image" = "''${candidate_images[$component]}" ] || return 1
      done
    }

    activate_selected() {
      postgres_changed=false
      api_changed=false
      web_changed=false
      app_stopped=false
      component_selected postgres && postgres_changed=true
      component_selected api && api_changed=true
      component_selected web && web_changed=true

      if $postgres_changed; then
        systemctl stop podman-montra-web.service podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service || return 1
        app_stopped=true
        systemctl restart podman-montra-postgres.service || return 1
      fi
      if component_selected embedding; then
        systemctl restart podman-montra-embedding.service || return 1
      fi
      if component_selected detector; then
        systemctl restart podman-montra-detector.service || return 1
      fi
      if $api_changed || $postgres_changed; then
        systemctl start montra-deploy-initialize.service || return 1
        systemctl restart podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service || return 1
        app_stopped=false
      fi
      if $web_changed || $postgres_changed; then
        systemctl restart podman-montra-web.service || return 1
      fi
    }

    restore_application_services() {
      if $app_stopped; then
        systemctl restart podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service || return 1
        systemctl restart podman-montra-web.service || return 1
        app_stopped=false
      fi
    }

    runtime_healthy() {
      systemctl is-active --quiet \
        podman-montra-postgres.service \
        podman-montra-meilisearch.service \
        podman-montra-embedding.service \
        podman-montra-detector.service \
        podman-montra-api.service \
        podman-montra-worker.service \
        podman-montra-integration-worker.service \
        podman-montra-web.service \
        && podman exec montra-postgres pg_isready -U montra -d montra >/dev/null \
        && podman exec montra-embedding python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8811/health')" \
        && podman exec montra-detector python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8812/health/ready')" \
        && curl -fsS http://127.0.0.1:8788/health/ready >/dev/null \
        && curl -fsS http://127.0.0.1:8091/ >/dev/null
    }

    candidate_dependencies_ready() {
      if component_selected embedding; then
        podman exec montra-embedding python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8811/health/ready')" || return 1
      fi
      if component_selected detector; then
        podman exec montra-detector python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8812/health/ready')" || return 1
      fi
    }

    wait_for_runtime() {
      for _attempt in $(seq 1 120); do
        runtime_healthy && return 0
        sleep 2
      done
      journalctl \
        -u podman-montra-postgres.service \
        -u podman-montra-embedding.service \
        -u podman-montra-detector.service \
        -u podman-montra-api.service \
        -u podman-montra-worker.service \
        -u podman-montra-integration-worker.service \
        -u podman-montra-web.service \
        -n 200 --no-pager >&2
      return 1
    }

    verify_changed_containers() {
      state="$1"
      for component in "''${selected_components[@]}"; do
        if [ "$state" = candidate ]; then
          expected_image="''${candidate_images[$component]}"
        else
          expected_image="''${previous_images[$component]}"
        fi
        case "$component" in
          api) containers=(montra-api montra-worker montra-integration-worker) ;;
          *) containers=("montra-$component") ;;
        esac
        for container in "''${containers[@]}"; do
          running_image_name="$(podman inspect "$container" --format '{{.ImageName}}')" || return 1
          running_image="$(podman image inspect "$running_image_name" --format '{{.Id}}')" || return 1
          [ "$running_image" = "$expected_image" ] || {
            echo "$container runs $running_image, expected $expected_image" >&2
            return 1
          }
        done
      done
    }

    rollback_application() {
      echo "Montra rollout failed; restoring selected previous images. Database migrations are not reversed." >&2
      restore_previous_tags || return 1
      activate_selected || {
        restore_application_services || true
        return 1
      }
      restore_application_services || return 1
      wait_for_runtime || return 1
      verify_changed_containers previous || return 1
      curl -fsS https://montra.style/ >/dev/null || return 1
      echo "ROLLBACK_OK montra" >&2
    }

    fail_with_rollback() {
      reason="$1"
      echo "$reason" >&2
      if rollback_application; then
        echo "Deployment failed; verified Montra rollback completed." >&2
      else
        echo "FATAL: Montra deployment and rollback verification both failed." >&2
      fi
      return 1
    }

    if ! promote_candidates; then
      if restore_previous_tags; then
        echo "Montra candidate promotion failed before service replacement; previous tags were restored" >&2
      else
        echo "FATAL: Montra candidate promotion and previous-tag restoration both failed" >&2
      fi
      exit 1
    fi
    if ! activate_selected; then
      restore_application_services || true
      fail_with_rollback "Montra candidate activation failed"
      exit 1
    fi
    if ! wait_for_runtime; then
      fail_with_rollback "Montra candidate runtime did not become ready"
      exit 1
    fi
    if ! candidate_dependencies_ready; then
      fail_with_rollback "Montra candidate model service did not become ready"
      exit 1
    fi
    if ! verify_changed_containers candidate; then
      fail_with_rollback "Montra running image verification failed"
      exit 1
    fi
    if ! curl -fsS https://montra.style/ >/dev/null; then
      fail_with_rollback "Montra public health check failed"
      exit 1
    fi

    ${pruneImages}
    printf 'DEPLOY_OK montra %s components=%s\n' "$revision" "$(IFS=,; echo "''${selected_components[*]}")"
  '';

  triggerMontraDeploy = pkgs.writeShellScript "trigger-deploy-montra" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    [ "$#" -eq 1 ] || { echo "expected the exact signed Montra JSON payload" >&2; exit 1; }
    payload="$1"
    now="$(date +%s)"
    ${pkgs.bash}/bin/bash ${./validate-montra-delivery.sh} \
      "$payload" "$now" /var/lib/montra/deploy-deliveries ${./montra-payload.jq}
    revision="$(jq -er .sha <<< "$payload")"
    delivery_id="$(jq -er .delivery_id <<< "$payload")"
    components="$(jq -ec .components <<< "$payload")"

    ${pkgs.systemd}/bin/systemd-run \
      --quiet \
      --wait \
      --collect \
      --pipe \
      --service-type=oneshot \
      --unit="deploy-montra-$delivery_id" \
      --property=TimeoutStartSec=60min \
      ${montraDeploy} "$revision" "$components"
    printf 'DEPLOY_OK montra %s\n' "$revision"
  '';

  unpromptedDeploy = pkgs.writeShellScript "deploy-unprompted" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    [ "$#" -eq 5 ] || { echo "expected Unprompted revision and four image digests" >&2; exit 1; }
    revision="$1"
    digests=("$2" "$3" "$4" "$5")
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "invalid Unprompted revision" >&2; exit 1; }
    for digest in "''${digests[@]}"; do
      [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "invalid Unprompted image digest" >&2; exit 1; }
    done

    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    if [ ! -f ${config.sops.templates."unprompted-production-env".path} ]; then
      echo "Unprompted production env is not configured" >&2
      exit 1
    fi

    components=(api worker web migrate)
    declare -A previous_images=()
    previous_revision=""

    # Promotion is forbidden unless all four rollback targets exist, resolve to
    # concrete image IDs, and carry one valid common revision.
    for component in "''${components[@]}"; do
      image="ghcr.io/rodrgds/unprompted-$component"
      previous_image="$(podman image inspect "$image:latest" --format '{{.Id}}')" || {
        echo "missing previous $component image; refusing promotion without a complete rollback set" >&2
        exit 1
      }
      [ -n "$previous_image" ] || {
        echo "previous $component image ID is empty" >&2
        exit 1
      }
      previous_images[$component]="$previous_image"
      component_revision="$(podman image inspect "$previous_image" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
      [[ "$component_revision" =~ ^[0-9a-f]{40}$ ]] || {
        echo "previous $component image has an invalid revision label" >&2
        exit 1
      }
      if [ -z "$previous_revision" ]; then
        previous_revision="$component_revision"
      elif [ "$component_revision" != "$previous_revision" ]; then
        echo "previous Unprompted images do not share one revision" >&2
        exit 1
      fi
    done

    systemctl restart packages-registry-login.service
    for index in "''${!components[@]}"; do
      component="''${components[$index]}"
      digest="''${digests[$index]}"
      image="ghcr.io/rodrgds/unprompted-$component"
      candidate="$image@$digest"
      podman pull "$candidate"
      image_revision="$(podman image inspect "$candidate" --format '{{index .Labels "org.opencontainers.image.revision"}}')"
      [ "$image_revision" = "$revision" ] || {
        echo "$component candidate revision $image_revision does not match $revision" >&2
        exit 1
      }
    done

    verify_previous_tags() {
      for component in "''${components[@]}"; do
        image="ghcr.io/rodrgds/unprompted-$component"
        restored_image="$(podman image inspect "$image:latest" --format '{{.Id}}')" || return 1
        [ "$restored_image" = "''${previous_images[$component]}" ] || {
          echo "restored $component tag maps to $restored_image, expected ''${previous_images[$component]}" >&2
          return 1
        }
        restored_revision="$(podman image inspect "$image:latest" --format '{{index .Labels "org.opencontainers.image.revision"}}')" || return 1
        [ "$restored_revision" = "$previous_revision" ] || {
          echo "restored $component revision $restored_revision does not match $previous_revision" >&2
          return 1
        }
      done
    }

    restore_previous_tags() {
      for component in "''${components[@]}"; do
        image="ghcr.io/rodrgds/unprompted-$component"
        podman tag "''${previous_images[$component]}" "$image:latest" || return 1
      done
      verify_previous_tags
    }

    promote_candidate_tags() {
      for index in "''${!components[@]}"; do
        component="''${components[$index]}"
        digest="''${digests[$index]}"
        image="ghcr.io/rodrgds/unprompted-$component"
        podman tag "$image@$digest" "$image:latest" || return 1
      done
    }

    rollback_application() {
      echo "Unprompted rollout failed; restoring and verifying revision $previous_revision. Database migrations are not reversed." >&2
      restore_previous_tags || return 1
      systemctl restart podman-unprompted-api.service podman-unprompted-worker.service || return 1
      systemctl restart podman-unprompted-web.service || return 1
      for attempt in $(seq 1 30); do
        if systemctl is-active --quiet podman-unprompted-api.service podman-unprompted-worker.service podman-unprompted-web.service \
          && curl -fsS http://127.0.0.1:4100/ready >/dev/null \
          && curl -fsS http://127.0.0.1:3210/ >/dev/null \
          && curl -fsS https://api.unprompted.to/ready >/dev/null \
          && curl -fsS https://unprompted.to/ >/dev/null; then
          healthy=true
          for component in api worker web; do
            running_image="$(podman inspect "unprompted-$component" --format '{{.Image}}')" || return 1
            if [ "$running_image" != "''${previous_images[$component]}" ]; then
              echo "restored $component container uses $running_image, expected ''${previous_images[$component]}" >&2
              healthy=false
            fi
          done
          if [ "$healthy" = true ]; then
            verify_previous_tags || return 1
            echo "ROLLBACK_OK unprompted $previous_revision" >&2
            return 0
          fi
        fi
        sleep 2
      done
      journalctl -u podman-unprompted-api.service -u podman-unprompted-worker.service -u podman-unprompted-web.service -n 160 --no-pager >&2
      return 1
    }

    fail_with_rollback() {
      reason="$1"
      echo "$reason" >&2
      if rollback_application; then
        echo "Deployment failed; verified rollback completed." >&2
      else
        echo "FATAL: deployment failed and rollback verification failed; inspect the unit journal and preserved image tags before retrying." >&2
      fi
      return 1
    }

    if ! promote_candidate_tags; then
      fail_with_rollback "candidate tag promotion failed"
      exit 1
    fi

    # This deployment-only migration unit is not required by the running app,
    # so a failed migration leaves the previous containers serving.
    if ! systemctl start unprompted-deploy-initialize.service; then
      journalctl -u unprompted-deploy-initialize.service -n 160 --no-pager >&2
      fail_with_rollback "candidate database migration failed"
      exit 1
    fi

    if ! systemctl stop podman-unprompted-web.service podman-unprompted-worker.service podman-unprompted-api.service; then
      fail_with_rollback "failed to stop the previous application services"
      exit 1
    fi
    if ! systemctl start podman-unprompted-api.service podman-unprompted-worker.service; then
      fail_with_rollback "failed to start candidate API or worker"
      exit 1
    fi

    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:4100/ready >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u podman-unprompted-api.service -u podman-unprompted-worker.service -n 160 --no-pager >&2
        fail_with_rollback "candidate API did not become ready"
        exit 1
      fi
      sleep 2
    done

    if ! systemctl start podman-unprompted-web.service; then
      fail_with_rollback "failed to start candidate web service"
      exit 1
    fi
    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:3210/ >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u podman-unprompted-web.service -n 160 --no-pager >&2
        fail_with_rollback "candidate web service did not become ready"
        exit 1
      fi
      sleep 2
    done

    for component in api worker web; do
      image="ghcr.io/rodrgds/unprompted-$component"
      expected_image="$(podman image inspect "$image:latest" --format '{{.Id}}')"
      running_image="$(podman inspect "unprompted-$component" --format '{{.Image}}')"
      [ "$running_image" = "$expected_image" ] || {
        echo "$component is not running the approved image" >&2
        fail_with_rollback "candidate container image verification failed"
        exit 1
      }
    done

    if ! systemctl is-active --quiet podman-unprompted-api.service podman-unprompted-worker.service podman-unprompted-web.service; then
      fail_with_rollback "one or more candidate services are inactive"
      exit 1
    fi
    if ! curl -fsS https://api.unprompted.to/ready >/dev/null \
      || ! curl -fsS https://unprompted.to/ >/dev/null; then
      fail_with_rollback "candidate public health checks failed"
      exit 1
    fi
    podman image prune --force
    echo "DEPLOY_OK unprompted $revision"
  '';

  triggerUnpromptedDeploy = pkgs.writeShellScript "trigger-deploy-unprompted" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    [ "$#" -eq 1 ] || { echo "expected the exact signed Unprompted JSON payload" >&2; exit 1; }
    payload="$1"
    revision="$(jq -er '.sha | select(type == "string")' <<< "$payload")"
    issued_at="$(jq -er '.issued_at | select(type == "number" and . == floor)' <<< "$payload")"
    delivery_id="$(jq -er '.delivery_id | select(type == "string")' <<< "$payload")"
    repository="$(jq -er '.repository | select(type == "string")' <<< "$payload")"
    digests=(
      "$(jq -er '.api_digest | select(type == "string")' <<< "$payload")"
      "$(jq -er '.worker_digest | select(type == "string")' <<< "$payload")"
      "$(jq -er '.web_digest | select(type == "string")' <<< "$payload")"
      "$(jq -er '.migrate_digest | select(type == "string")' <<< "$payload")"
    )
    [ "$repository" = "rodrgds/unprompted" ] || { echo "invalid Unprompted repository" >&2; exit 1; }
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "invalid Unprompted revision" >&2; exit 1; }
    [[ "$issued_at" =~ ^[0-9]{1,10}$ ]] || { echo "invalid Unprompted issued_at" >&2; exit 1; }
    [[ "$delivery_id" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,127}$ ]] || { echo "invalid Unprompted delivery ID" >&2; exit 1; }
    for digest in "''${digests[@]}"; do
      [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "invalid Unprompted image digest" >&2; exit 1; }
    done
    now="$(date +%s)"
    if [ "$issued_at" -lt "$((now - 300))" ]; then
      echo "Unprompted delivery is older than five minutes" >&2
      exit 1
    fi
    if [ "$issued_at" -gt "$((now + 60))" ]; then
      echo "Unprompted delivery timestamp is too far in the future" >&2
      exit 1
    fi

    delivery_path="/var/lib/unprompted/deploy-deliveries/$delivery_id"
    if ! mkdir "$delivery_path" 2>/dev/null; then
      echo "duplicate Unprompted delivery ID" >&2
      exit 1
    fi
    printf '%s\n' "$issued_at" > "$delivery_path/issued_at"
    printf '%s\n' "$revision" > "$delivery_path/revision"

    ${pkgs.systemd}/bin/systemd-run \
      --quiet \
      --wait \
      --collect \
      --service-type=oneshot \
      --unit="deploy-unprompted-$delivery_id" \
      --property=TimeoutStartSec=60min \
      ${unpromptedDeploy} "$revision" "''${digests[@]}"
    printf 'DEPLOY_OK unprompted %s\n' "$revision"
  '';

  triggerDeploy =
    name:
    pkgs.writeShellScript "trigger-deploy-${name}" ''
      set -euo pipefail
      ${pkgs.systemd}/bin/systemctl start deploy-${name}.service
      echo "DEPLOY_OK ${name}"
    '';
in
{
  options.vps.hosting.deployments = {
    enable = lib.mkEnableOption "Enable signed application deployments";
  };

  config = lib.mkIf cfg.enable {
    sops.templates."webhook-hooks" = {
      content = ''
        [
          {
            "id": "deploy-personal-website",
            "execute-command": "${triggerDeploy "personal-website"}",
            "include-command-output-in-response": true,
            "trigger-rule": {
              "match": {
                "type": "payload-hmac-sha256",
                "secret": "${config.sops.placeholder.deploy_webhook_secret}",
                "parameter": {
                  "source": "header",
                  "name": "X-Hub-Signature-256"
                }
              }
            }
          },
          {
            "id": "deploy-openpost",
            "execute-command": "${triggerOpenpostDeploy}",
            "include-command-output-in-response": true,
            "pass-arguments-to-command": [
              { "source": "payload", "name": "sha" },
              { "source": "payload", "name": "tag" },
              { "source": "payload", "name": "digest" }
            ],
            "trigger-rule": {
              "and": [
                {
                  "match": {
                    "type": "payload-hmac-sha256",
                    "secret": "${config.sops.placeholder.deploy_webhook_secret}",
                    "parameter": {
                      "source": "header",
                      "name": "X-Hub-Signature-256"
                    }
                  }
                },
                {
                  "match": {
                    "type": "value",
                    "value": "getopenpost/openpost",
                    "parameter": {
                      "source": "payload",
                      "name": "repository"
                    }
                  }
                }
              ]
            }
          },
          {
            "id": "deploy-montra",
            "execute-command": "${triggerMontraDeploy}",
            "include-command-output-in-response": true,
            "pass-arguments-to-command": [
              { "source": "entire-payload" }
            ],
            "trigger-rule": {
              "and": [
                {
                  "match": {
                    "type": "payload-hmac-sha256",
                    "secret": "${config.sops.placeholder.deploy_webhook_secret}",
                    "parameter": {
                      "source": "header",
                      "name": "X-Hub-Signature-256"
                    }
                  }
                },
                {
                  "match": {
                    "type": "value",
                    "value": "rodrgds/montra",
                    "parameter": {
                      "source": "payload",
                      "name": "repository"
                    }
                  }
                }
              ]
            }
          },
          {
            "id": "deploy-unprompted",
            "execute-command": "${triggerUnpromptedDeploy}",
            "include-command-output-in-response": true,
            "pass-arguments-to-command": [
              { "source": "entire-payload" }
            ],
            "trigger-rule": {
              "and": [
                {
                  "match": {
                    "type": "payload-hmac-sha256",
                    "secret": "${config.sops.placeholder.unprompted_deploy_webhook_secret}",
                    "parameter": {
                      "source": "header",
                      "name": "X-Hub-Signature-256"
                    }
                  }
                },
                {
                  "match": {
                    "type": "value",
                    "value": "rodrgds/unprompted",
                    "parameter": {
                      "source": "payload",
                      "name": "repository"
                    }
                  }
                }
              ]
            }
          }
        ]
      '';
      mode = "0400";
      restartUnits = [ "webhook-deploy.service" ];
    };

    vps.caddy.internalPorts."webhooks.rgo.pt" = 9000;

    systemd.services.webhook-deploy = {
      description = "GitHub Webhook for Deploys";
      serviceConfig = {
        ExecStart = "${pkgs.webhook}/bin/webhook -hooks=${
          config.sops.templates."webhook-hooks".path
        } -verbose";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.deploy-personal-website = {
      description = "Deploy the verified personal website main branch";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = personalWebsiteDeploy;
        TimeoutStartSec = "15min";
      };
    };

  };
}
