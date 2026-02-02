{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.ungoogled-chromium;
  inherit (constants) isLinux;
in
{
  options.apps.ungoogled-chromium = {
    enable = lib.mkEnableOption "Enable Ungoogled Chromium";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.ungoogled-chromium ];
      })
    ]
  );
}
