{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.redshift;
  inherit (constants) isLinux;
in
{
  options.apps.redshift = {
    enable = lib.mkEnableOption "Enable Redshift";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        systemd.user.services.redshift = lib.mkIf isLinux {
          Unit = {
            Description = "Redshift color temperature adjuster";
            PartOf = [ "graphical-session.target" ];
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.redshift}/bin/redshift -l ${config.sops.placeholder.location_latitude}:${config.sops.placeholder.location_longitude}";
            Restart = "always";
          };
        };
      };
  };
}
