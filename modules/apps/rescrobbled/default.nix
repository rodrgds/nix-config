{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.rescrobbled;
  inherit (constants) isLinux;
in
{
  options.apps.rescrobbled = {
    enable = lib.mkEnableOption "Enable Rescrobbled Last.fm scrobbler";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        home.packages = [ pkgs.rescrobbled ];

        systemd.user.services.rescrobbled = lib.mkIf isLinux {
          Unit = {
            Description = "MPRIS scrobbler daemon";
            After = [ "graphical-session.target" ];
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
          Service = {
            ExecStart = "${pkgs.rescrobbled}/bin/rescrobbled";
            Restart = "always";
            RestartSec = "5s";
          };
        };

        sops.templates."rescrobbled-config.toml" = {
          content = ''
            lastfm-key = "''${config.sops.placeholder.lastfm_api_key}"
            lastfm-secret = "''${config.sops.placeholder.lastfm_secret}"
            lastfm-user = "''${config.sops.placeholder.lastfm_username}"
            player-whitelist = [ "chromium" ]
            min-play-time = 30
          '';
          path = "/home/${username}/.config/rescrobbled/config.toml";
        };
      };
  };
}
