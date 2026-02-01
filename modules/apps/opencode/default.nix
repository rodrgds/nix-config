{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.opencode;
in
{
  options.apps.opencode = {
    enable = lib.mkEnableOption "Enable Opencode CLI";
  };

  config = lib.mkIf cfg.enable {
    # Install opencode CLI
    environment.systemPackages = [ pkgs.opencode ];

    home-manager.users.${username} =
      { ... }:
      {
        programs.opencode = {
          enable = true;
          settings = {
            theme = "gruvbox";
            autoupdate = true;
          };
        };
      };
  };
}
