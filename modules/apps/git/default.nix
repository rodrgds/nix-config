{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.git;
  inherit (constants) isDarwin;
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
              email = config.sops.placeholder.user_email;
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;

            # macOS-specific: use osxkeychain for credential storage
            credential.helper = lib.mkIf isDarwin "osxkeychain";
          };
        };
      };
  };
}
