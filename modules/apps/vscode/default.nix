{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.vscode;
in
{
  options.apps.vscode = {
    enable = lib.mkEnableOption "Enable VS Code";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.vscode ];
  };
}
