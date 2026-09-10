{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.keepingyouawake;
in
{
  options.darwin.apps.keepingyouawake.enable =
    lib.mkEnableOption "the KeepingYouAwake menu bar control";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isDarwin;
        message = "darwin.apps.keepingyouawake is only supported on macOS";
      }
    ];

    homebrew.casks = [ "keepingyouawake" ];

    # Launchd owns startup. Quitting the app must still release its assertion.
    home-manager.users.${username}.launchd.agents.keepingyouawake = {
      enable = true;
      config = {
        ProgramArguments = [ "/Applications/KeepingYouAwake.app/Contents/MacOS/KeepingYouAwake" ];
        RunAtLoad = true;
        ProcessType = "Interactive";
      };
    };
  };
}
