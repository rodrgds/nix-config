{
  lib,
  config,
  username,
  system,
  ...
}:
let
  cfg = config.core.downloads-cleanup;
  isDarwin = lib.hasSuffix "-darwin" system;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
in
{
  options.core.downloads-cleanup = {
    enable = lib.mkEnableOption "Enable automatic cleanup of Downloads folder (files older than 30 days)";
  };

  config = lib.mkIf cfg.enable (
    if isDarwin then
      {
        # macOS: Use launchd agent
        launchd.agents.cleanup-downloads = {
          serviceConfig = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              "find ${homeDir}/Downloads -type f -mtime +30 -delete"
            ];
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 0;
              }
            ];
            StandardOutPath = "/tmp/cleanup-downloads.log";
            StandardErrorPath = "/tmp/cleanup-downloads.err";
          };
        };
      }
    else
      {
        # NixOS: Use systemd tmpfiles
        systemd.tmpfiles.rules = [
          "d ${homeDir}/Downloads 0755 ${username} ${username} 30d -"
        ];
      }
  );
}
