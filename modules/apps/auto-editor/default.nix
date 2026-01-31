{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.auto-editor;
in
{
  options.apps.auto-editor = {
    enable = lib.mkEnableOption "Enable auto-editor";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.auto-editor ];
  };
}
