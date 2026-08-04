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
    pkgs.jq
    pkgs.gnugrep
    pkgs.podman
    pkgs.systemd
    pkgs.util-linux
  ];

  pruneImages = ''
    podman image prune --all --force --build-cache
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

  eduDeploy = pkgs.writeShellScript "deploy-edu" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    systemctl restart edu-site.service
    curl --fail --silent --show-error \
      --resolve edu.rgo.pt:443:127.0.0.1 \
      https://edu.rgo.pt/ >/dev/null
  '';

  openpostDeploy = pkgs.writeShellScript "deploy-openpost" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    revision="''${1:-}"
    release_tag="''${2:-}"
    digest="''${3:-}"
    image_name=ghcr.io/rodrgds/openpost

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
      candidate_args+=(--env "$environment")
    done < <(podman inspect openpost | jq -r '.[0].Config.Env[]')
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
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    systemctl restart montra-registry-login.service
    for image in \
      ghcr.io/rodrgds/montra-postgres:latest \
      ghcr.io/rodrgds/montra-embedding:latest \
      ghcr.io/rodrgds/montra-detector:latest \
      ghcr.io/rodrgds/montra-api:latest \
      ghcr.io/rodrgds/montra-web:latest; do
      podman pull "$image"
    done

    systemctl stop podman-montra-web.service podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service
    systemctl restart podman-montra-postgres.service podman-montra-embedding.service podman-montra-detector.service
    systemctl restart montra-initialize.service
    systemctl start podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service

    for attempt in $(seq 1 90); do
      if curl -fsS http://127.0.0.1:8788/health/ready >/dev/null; then
        break
      fi
      if [ "$attempt" = 90 ]; then
        journalctl -u podman-montra-api.service -n 160 --no-pager >&2
        exit 1
      fi
      sleep 2
    done

    systemctl start podman-montra-web.service
    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:8091/ >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u podman-montra-web.service -n 120 --no-pager >&2
        exit 1
      fi
      sleep 2
    done

    systemctl is-active --quiet podman-montra-detector.service podman-montra-api.service podman-montra-worker.service podman-montra-integration-worker.service podman-montra-web.service
    curl -fsS https://montra.style/ >/dev/null
    ${pruneImages}
  '';

  unpromptedDeploy = pkgs.writeShellScript "deploy-unprompted" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    if [ ! -f /var/lib/unprompted/production.env ]; then
      echo "Unprompted production env is not configured" >&2
      exit 1
    fi

    systemctl restart unprompted-build.service
    systemctl is-active --quiet unprompted-api.service unprompted-worker.service unprompted-web.service

    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:4100/ready >/dev/null \
        && curl -fsS http://127.0.0.1:3210/ >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u unprompted-api.service -u unprompted-web.service -n 160 --no-pager >&2
        exit 1
      fi
      sleep 2
    done

    curl -fsS https://api.unprompted.to/ready >/dev/null
    curl -fsS https://unprompted.to/ >/dev/null
    ${pruneImages}
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
            "id": "deploy-edu",
            "execute-command": "${triggerDeploy "edu"}",
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
                    "value": "rodrgds/openpost",
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
            "execute-command": "${triggerDeploy "montra"}",
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
            "id": "deploy-unprompted",
            "execute-command": "${triggerDeploy "unprompted"}",
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
          }
        ]
      '';
      mode = "0644";
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

    systemd.services.deploy-edu = {
      description = "Deploy the verified edu.rgo.pt main branch";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = eduDeploy;
        TimeoutStartSec = "5min";
      };
    };

    systemd.services.deploy-montra = {
      description = "Deploy verified Montra production images";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = montraDeploy;
        TimeoutStartSec = "30min";
      };
    };

    systemd.services.deploy-unprompted = {
      description = "Deploy verified Unprompted main from source";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = unpromptedDeploy;
        TimeoutStartSec = "60min";
      };
    };
  };
}
