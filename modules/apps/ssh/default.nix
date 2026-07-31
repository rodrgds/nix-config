# SSH client configuration
{
  config,
  lib,
  username,
  ...
}:
let
  cfg = config.apps.ssh;
  isGhosttyEnabled = config.apps.ghostty.enable or false;
in
{
  options.apps.ssh = {
    enable = lib.mkEnableOption "Enable SSH";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { lib, ... }:
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          # When using Ghostty, set TERM to a known value for all SSH connections
          # This fixes 'xterm-ghostty: unknown terminal type' on remote servers
          settings."*" = lib.mkIf isGhosttyEnabled {
            SetEnv.TERM = "xterm-256color";
          };
        };

        # Fix for nix shells with buildFHSEnv - SSH config needs to be a regular file, not a symlink
        home.file.".ssh/config".force = true;
        home.activation.fixSshPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run install -d -m 0700 "$HOME/.ssh"
          if [ -L "$HOME/.ssh/config" ]; then
            src="$(readlink -f "$HOME/.ssh/config")"
            run rm -f "$HOME/.ssh/config"
            run install -m 0600 "$src" "$HOME/.ssh/config"
          fi
        '';
      };
  };
}
