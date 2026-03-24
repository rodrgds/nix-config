{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.php;
in
{
  options.apps.php = {
    enable = lib.mkEnableOption "Enable PHP development environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      php
      phpPackages.composer
      phpExtensions.gd
      phpExtensions.mbstring
      phpExtensions.xml
      phpExtensions.curl
      phpExtensions.zip
      phpExtensions.pdo
      phpExtensions.pdo_sqlite
      phpExtensions.sqlite3
      phpExtensions.mysqlnd
      phpExtensions.redis
    ];
  };
}
