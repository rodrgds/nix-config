{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.worktrunk;

  bashInit = pkgs.runCommand "worktrunk-shell-init-bash" { } ''
    ${pkgs.worktrunk}/bin/wt config shell init bash > "$out"
  '';

  zshInit = pkgs.runCommand "worktrunk-shell-init-zsh" { } ''
    ${pkgs.worktrunk}/bin/wt config shell init zsh > "$out"
  '';
in
{
  options.apps.worktrunk = {
    enable = lib.mkEnableOption "Enable Worktrunk git worktree manager";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.packages = [ pkgs.worktrunk ];

      # Source the version-matched shell integration from the installed binary.
      # Do not let `wt config shell install` mutate rc files directly.
      programs.bash.initExtra = lib.mkAfter ''
        if [ -f ${bashInit} ]; then
          source ${bashInit}
        fi
      '';

      programs.zsh.initExtra = lib.mkAfter ''
        if [ -f ${zshInit} ]; then
          source ${zshInit}
        fi
      '';
    };
  };
}
