{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.worktrunk;
in
{
  options.apps.worktrunk.enable = lib.mkEnableOption "Worktrunk worktree management";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.worktrunk ];

    home-manager.users.${username} = {
      xdg.configFile."worktrunk/config.toml".text = ''
        worktree-path = "~/dev/worktrees/{{ repo }}/{{ branch | sanitize }}"
      '';

      programs.bash.initExtra = lib.mkAfter ''
        eval "$(command wt config shell init bash)"
      '';
    };
  };
}
