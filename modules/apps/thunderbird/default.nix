{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.thunderbird;
  inherit (constants) isLinux;
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
