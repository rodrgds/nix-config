{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.mangohud;
  isLinux = lib.hasSuffix "-linux" system;
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
