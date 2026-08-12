{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.cs2;
  inherit (constants) isLinux moduleDir;
in
{
  options.apps.cs2 = {
    enable = lib.mkEnableOption "Enable CS2";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = _: {
      home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg".source =
        ./autoexec.cfg;
      home.file.".local/share/Steam/steamapps/common/csgo legacy/csgo/cfg/autoexec.cfg".source =
        ./autoexec-csgo.cfg;

      home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/practice.cfg".source =
        ./practice.cfg;

      home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/simulate.cfg".source =
        ./simulate.cfg;

      home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/surf.cfg".source =
        ./surf.cfg;

      # home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/gamestate_integration_score.cfg".text =
      #   ''
      #     "GSI"
      #     {
      #       "uri" "http://localhost:3000"
      #       "timeout" "5.0"
      #       "buffer" "0.1"
      #       "throttle" "0.5"
      #       "heartbeat" "30.0"
      #       "data"
      #       {
      #         "provider" "1"
      #         "map" "1"
      #         "round" "1"
      #         "player_id" "1"
      #         "player_state" "1"
      #         "player_weapons" "1"
      #       }
      #     }
      #   '';

      # systemd.user.services.cs2-gsi = lib.mkIf isLinux {
      #   Unit = {
      #     Description = "CS2 Game State Integration Server";
      #   };
      #   Install = {
      #     WantedBy = [ "default.target" ];
      #   };
      #   Service = {
      #     Type = "simple";
      #     ExecStart = "${pkgs.python3}/bin/python3 ${scriptDir}/cs2-gsi-server.py";
      #     Restart = "always";
      #     RestartSec = "5s";
      #     PrivateTmp = false;
      #     Environment = "HOME=/home/${username}";
      #   };
      # };

      programs.steam.config = lib.mkIf isLinux {
        enable = true;
        onSteamRunning = "close";
        apps.cs2-wayland = {
          id = 730;
          launchOptions = {
            wrappers = [
              (lib.getExe pkgs.gamemode)
              # (lib.getExe' pkgs.obs-studio-plugins.obs-vkcapture "obs-gamecapture")
              # (lib.getExe pkgs.mangohud)
              "${moduleDir}/apps/cs2/wrapper.sh"
            ];
            args = [
              "-novid"
              "-nojoy"
              "-fullscreen"
              "-h"
              "960"
              "-w"
              "1280"
              "+exec"
              "autoexec.cfg"
            ];
          };
        };
      };
    };
  };
}
