{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.git;
in
{
  options.apps.git = {
    enable = lib.mkEnableOption "Enable Git";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.git ];

    home-manager.users.${username} =
      { config, ... }:
      {
        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "rgo";
              email = config.sops.placeholder.user_email or "user@example.com";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;
          };
        };
      };
  };
}
