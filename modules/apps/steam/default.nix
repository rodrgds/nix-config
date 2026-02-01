{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.steam;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.steam = {
    enable = lib.mkEnableOption "Enable Steam";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        programs.steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
        };
      })
    ]
  );
}
