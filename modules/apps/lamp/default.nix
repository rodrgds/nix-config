{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.lamp;
in
{
  options.apps.lamp = {
    enable = lib.mkEnableOption "Enable LAMP stack (Apache + PHP + MariaDB)";
  };

  config = lib.mkIf cfg.enable {
    services.httpd = {
      enable = true;
      adminAddr = "admin@localhost";
      enablePHP = true;
      phpPackage = pkgs.php;
      virtualHosts = {
        "localhost" = {
          documentRoot = "/var/www/html";
        };
      };
    };

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
    };
  };
}
