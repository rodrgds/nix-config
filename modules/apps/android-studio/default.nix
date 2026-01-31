{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.android-studio;
in
{
  options.apps.android-studio = {
    enable = lib.mkEnableOption "Enable Android Studio";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.android-studio ];
  };
}
