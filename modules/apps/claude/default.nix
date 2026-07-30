{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.claude;
  inherit (constants) isLinux;
  installDir = ".local/share/npm-global";
  packageName = "@anthropic-ai/claude-code";
  updateScript = pkgs.writeShellScript "update-claude-cli" ''
    set -eu
    install_root="$HOME/${installDir}"
    mkdir -p "$install_root"
    exec ${pkgs.nodejs}/bin/npm install --global --prefix "$install_root" ${packageName}
  '';
in
{
  options.apps.claude = {
    enable = lib.mkEnableOption "Enable Claude";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    home-manager.users.${username} =
      { lib, ... }:
      {
        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        # Bootstrap only when absent; routine updates happen outside the
        # boot-critical Home Manager activation.
        home.activation.installClaudeCli = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          if isLinux then
            ''
              if [ ! -x "$HOME/${installDir}/bin/claude" ]; then
                ${updateScript}
              fi
            ''
          else
            ''
              ${updateScript}
            ''
        );

        systemd.user.services.update-claude-cli = {
          Unit.Description = "Update Claude Code from npm";
          Service = {
            Type = "oneshot";
            ExecStart = updateScript;
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };

        systemd.user.timers.update-claude-cli = {
          Unit.Description = "Periodically update Claude Code";
          Timer = {
            OnBootSec = "15m";
            OnUnitActiveSec = "1d";
            RandomizedDelaySec = "1h";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
  };
}
