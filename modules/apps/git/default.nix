{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.git;
  inherit (constants)
    isDarwin
    fullname
    email
    homeDir
    sshPublicKeys
    ;
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
            gpg.format = "ssh";
            user = {
              name = fullname;
              email = email;
              signingKey = "${homeDir}/.ssh/id_ed25519.pub";
            };
            commit.gpgsign = true;
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;

            gpg.ssh.allowedSignersFile = "${homeDir}/.config/git/allowed_signers";

            # macOS-specific: use osxkeychain for credential storage
            credential.helper = lib.mkIf isDarwin "osxkeychain";
          };
        };

        home.file.".config/git/allowed_signers".text =
          let
            keys = lib.attrValues sshPublicKeys;
            mkSignerLine = key: "${email} ${key}\n";
          in
          lib.concatMapStrings mkSignerLine keys;
      };
  };
}
