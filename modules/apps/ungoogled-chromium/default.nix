{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.ungoogled-chromium;
  isLinux = lib.hasSuffix "-linux" system;
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
