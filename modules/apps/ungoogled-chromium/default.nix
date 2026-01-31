{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.ungoogled-chromium;
in
{
  options.apps.ungoogled-chromium = {
    enable = lib.mkEnableOption "Enable Ungoogled Chromium";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ungoogled-chromium ];
  };
}
