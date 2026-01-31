{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.dunst;
in
{
  options.apps.dunst = {
    enable = lib.mkEnableOption "Enable Dunst notification daemon";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.dunst ];
    services.dbus.packages = [ pkgs.dunst ];

    home-manager.users.${username} =
      { ... }:
      {
        systemd.user.services.dunst = {
          Unit = {
            Description = "Dunst notification daemon";
            PartOf = [ "graphical-session.target" ];
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.dunst}/bin/dunst";
            Restart = "always";
          };
        };
      };
  };
}
