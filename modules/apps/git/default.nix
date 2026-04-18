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
  inherit (constants) isDarwin fullname email;
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
          extraConfig = {
            gpg.format = "ssh";
            user.signingkey = "~/.ssh/id_ed25519.pub";
            commit.gpgsign = true;
          };
          settings = {
            user = {
              name = fullname;
              email = email;
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
