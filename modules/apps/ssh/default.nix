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
    enable = lib.mkEnableOption "Enable SSH client configuration";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        # When using Ghostty, set TERM to a known value for all SSH connections
        # This fixes 'xterm-ghostty: unknown terminal type' on remote servers
        matchBlocks."*" = lib.mkIf isGhosttyEnabled {
          setEnv.TERM = "xterm-256color";
        };
      };
    };
  };
}
