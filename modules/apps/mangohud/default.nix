{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.mangohud;
  inherit (constants) isLinux;
in
{
  options.apps.mangohud = {
    enable = lib.mkEnableOption "Enable MangoHud";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.mangohud ];
      })
    ]
  );
}
