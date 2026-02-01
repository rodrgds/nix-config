{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.normcap;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.normcap = {
    enable = lib.mkEnableOption "Enable Normcap OCR tool";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.normcap ];
      })
    ]
  );
}
