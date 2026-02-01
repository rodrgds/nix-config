{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.dunst;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.dunst = {
    enable = lib.mkEnableOption "Enable Dunst notification daemon";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.dunst ];
        services.dbus.packages = [ pkgs.dunst ];
      })

      {
        home-manager.users.${username} =
          { ... }:
          {
            systemd.user.services.dunst = lib.mkIf isLinux {
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
      }
    ]
  );
}
