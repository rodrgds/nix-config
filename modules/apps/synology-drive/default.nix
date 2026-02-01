{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.synology-drive;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.synology-drive = {
    enable = lib.mkEnableOption "Enable Synology Drive Client";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { ... }:
      {
        home.packages = [ pkgs.synology-drive-client ];

        systemd.user.services.synology-drive = lib.mkIf isLinux {
          Unit = {
            Description = "Synology Drive Client";
            After = [ "graphical-session-pre.target" ];
          };
          Service = {
            Environment = "QT_STYLE_OVERRIDE=Fusion QT_QPA_PLATFORM=xcb";
            ExecStart = "${pkgs.synology-drive-client}/bin/synology-drive autostart";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
  };
}
