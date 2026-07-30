{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.codex;
  inherit (constants) isLinux;
  installDir = ".local/share/npm-global";
  packageName = "@openai/codex";
  updateScript = pkgs.writeShellScript "update-codex-cli" ''
    set -eu
    install_root="$HOME/${installDir}"
    mkdir -p "$install_root"
    exec ${pkgs.nodejs}/bin/npm install --global --prefix "$install_root" ${packageName}
  '';
in
{
  options.apps.codex = {
    enable = lib.mkEnableOption "Enable Codex";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;
    environment.systemPackages = lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];

    home-manager.users.${username} =
      { lib, ... }:
      {
        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        home.activation.installCodexCli = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          if isLinux then
            ''
              if [ ! -x "$HOME/${installDir}/bin/codex" ]; then
                ${updateScript}
              fi
            ''
          else
            ''
              ${updateScript}
            ''
        );

        systemd.user.services.update-codex-cli = {
          Unit.Description = "Update Codex from npm";
          Service = {
            Type = "oneshot";
            ExecStart = updateScript;
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };

        systemd.user.timers.update-codex-cli = {
          Unit.Description = "Periodically update Codex";
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
