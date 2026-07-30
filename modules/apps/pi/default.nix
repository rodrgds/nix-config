{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.pi;
  inherit (constants) isLinux;
  installDir = ".local/share/npm-global";
  packageName = "@mariozechner/pi-coding-agent";
  updateScript = pkgs.writeShellScript "update-pi-cli" ''
    set -eu
    install_root="$HOME/${installDir}"
    mkdir -p "$install_root"
    exec ${pkgs.nodejs}/bin/npm install --global --prefix "$install_root" ${packageName}
  '';
in
{
  options.apps.pi = {
    enable = lib.mkEnableOption "Enable Pi";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    # Essential CLI tools for pi
    environment.systemPackages = [
      pkgs.ripgrep
      pkgs.fd
    ];

    # Keep GUI tools able to resolve them
    home-manager.users.${username} =
      { lib, pkgs, ... }:
      {
        home.packages = [
          pkgs.ripgrep
          pkgs.fd
        ];

        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        home.activation.installPiCli = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          if isLinux then
            ''
              if [ ! -x "$HOME/${installDir}/bin/pi" ]; then
                ${updateScript}
              fi
            ''
          else
            ''
              ${updateScript}
            ''
        );

        systemd.user.services.update-pi-cli = {
          Unit.Description = "Update Pi from npm";
          Service = {
            Type = "oneshot";
            ExecStart = updateScript;
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };

        systemd.user.timers.update-pi-cli = {
          Unit.Description = "Periodically update Pi";
          Timer = {
            OnBootSec = "15m";
            OnUnitActiveSec = "1d";
            RandomizedDelaySec = "1h";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        home.file = {
          ".pi/agent/settings.json".text = builtins.toJSON {
            npmCommand = [
              "${pkgs.nodejs}/bin/npm"
              "--prefix"
              "${constants.homeDir}/${installDir}"
            ];
          };
        };
      };
  };
}
