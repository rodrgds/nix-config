{
  lib,
  config,
  pkgs,
  devenvPkg,
  username,
  ...
}:
let
  cfg = config.apps.development-tools;
in
{
  options.apps.development-tools = {
    enable = lib.mkEnableOption "Enable development tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.sqlite # SQLite database CLI
      devenvPkg
    ];
  };
}
