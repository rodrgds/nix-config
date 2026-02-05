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
  cfg = config.apps.teamspeak;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.teamspeak = {
    enable = lib.mkEnableOption "Enable TeamSpeak";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.teamspeak6-client ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "teamspeak-client" ];
      })
    ]
  );
}
