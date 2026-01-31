{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.normcap;
in
{
  options.apps.normcap = {
    enable = lib.mkEnableOption "Enable Normcap OCR tool";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.normcap ];
  };
}
