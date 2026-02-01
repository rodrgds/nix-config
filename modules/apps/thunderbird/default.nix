{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.thunderbird;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.thunderbird = {
    enable = lib.mkEnableOption "Enable Thunderbird";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.thunderbird ];
      })
    ]
  );
}
