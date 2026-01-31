{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship = {
    enable = lib.mkEnableOption "Enable Starship prompt";
  };

  config = lib.mkIf cfg.enable {
    programs.starship.enable = true;

    home-manager.users.${username} =
      { ... }:
      {
        programs.starship = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            scan_timeout = 1000;
            command_timeout = 1000;
          };
        };
      };
  };
}
