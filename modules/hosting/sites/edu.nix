{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.hosting.sites.edu;
in
{
  options.vps.hosting.sites.edu = {
    enable = lib.mkEnableOption "Enable the edu.rgo.pt static website";
    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/rodrgds/edu";
      description = "Git repository containing the static edu website.";
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch deployed by the edu site sync service.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.edu-site = {
      description = "Sync the edu.rgo.pt static website";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.git ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "edu-site";
        WorkingDirectory = "/var/lib/edu-site";
        ExecStart = pkgs.writeShellScript "sync-edu-site" ''
          set -euo pipefail
          if [ ! -d .git ]; then
            git clone --branch ${lib.escapeShellArg cfg.branch} --single-branch ${lib.escapeShellArg cfg.repository} .
          fi
          git fetch --prune origin ${lib.escapeShellArg cfg.branch}
          git reset --hard origin/${lib.escapeShellArg cfg.branch}
          git clean -fd
          test -f index.html
        '';
      };
    };

    services.caddy.virtualHosts."edu.rgo.pt" = {
      extraConfig = ''
        root * /var/lib/edu-site
        encode zstd gzip
        file_server
      '';
    };
  };
}
