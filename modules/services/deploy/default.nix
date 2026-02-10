# Deploy webhook for GitHub push-to-deploy
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.deploy;
in
{
  options.vps.deploy = {
    enable = lib.mkEnableOption "GitHub deploy webhook";
    secret = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Webhook secret for GitHub";
    };
  };

  config = lib.mkIf cfg.enable {
    services.webhook = {
      enable = true;
      port = 9000;
      openFirewall = true;
    };

    environment.etc."scripts/redeploy.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        set -e

        cd /etc/nixos

        echo "Updating flakes..."
        nix flake update

        echo "Rebuilding system..."
        nixos-rebuild switch --flake .#rgo-vps

        echo "Deployment complete!"
      '';
    };

    environment.etc."webhook-hooks.json" = {
      mode = "0644";
      text = ''
        [
          {
            "id": "redeploy",
            "execute-command": "/etc/scripts/redeploy.sh",
            "pass-arguments-to-command": [],
            "trigger-rule": {
              "match": {
                "type": "payload-hash-sha1",
                "secret": "${cfg.secret}",
                "parameter": {
                  "source": "header",
                  "name": "X-Hub-Signature-256"
                }
              }
            }
          }
        ]
      '';
    };

    systemd.services.webhook-deploy = {
      description = "GitHub Webhook for Deploys";
      serviceConfig = {
        ExecStart = "${pkgs.webhook}/bin/webhook -hooks=/etc/webhook-hooks.json -verbose";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
