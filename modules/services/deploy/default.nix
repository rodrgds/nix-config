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
  };

  config = lib.mkIf cfg.enable {
    sops.templates."webhook-hooks" = {
      content = ''
        [
          {
            "id": "redeploy",
            "execute-command": "/etc/scripts/redeploy.sh",
            "pass-arguments-to-command": [],
            "trigger-rule": {
              "match": {
                "type": "payload-hash-sha256",
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
    };

    environment.etc."scripts/redeploy.sh" = {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        set -e

        export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

        echo "Redeploying personal site..."
        systemctl restart personal-site personal-site-run

        echo "Deployment complete!"
      '';
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
  };
}
