{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.deploy;
  maintenancePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.curl
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

  openpostDeploy = pkgs.writeShellScript "deploy-openpost" ''
    set -euo pipefail
    export PATH=${maintenancePath}:$PATH
    exec 9>/run/podman-maintenance.lock
    flock --exclusive 9

    podman pull ghcr.io/rodrgds/openpost:latest
    systemctl restart podman-openpost.service

    for attempt in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:8090/api/v1/ready >/dev/null; then
        break
      fi
      if [ "$attempt" = 60 ]; then
        journalctl -u podman-openpost.service -n 120 --no-pager >&2
        exit 1
      fi
      sleep 2
    done

    curl -fsS https://app.openpost.social/api/v1/ready >/dev/null
    ${pruneImages}
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
      ghcr.io/rodrgds/montra-api:latest \
      ghcr.io/rodrgds/montra-web:latest; do
      podman pull "$image"
    done

    systemctl stop podman-montra-web.service podman-montra-api.service podman-montra-worker.service
    systemctl restart podman-montra-postgres.service podman-montra-embedding.service
    systemctl restart montra-initialize.service
    systemctl start podman-montra-api.service podman-montra-worker.service

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

    systemctl is-active --quiet podman-montra-api.service podman-montra-worker.service podman-montra-web.service
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
  options.vps.deploy = {
    enable = lib.mkEnableOption "Enable deploy";
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
            "execute-command": "${triggerDeploy "openpost"}",
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

    systemd.services.deploy-openpost = {
      description = "Deploy OpenPost after a verified release build";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = openpostDeploy;
        TimeoutStartSec = "15min";
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
