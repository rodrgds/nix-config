{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.lamp;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.lamp = {
    enable = lib.mkEnableOption "Enable LAMP stack (Apache + PHP + MariaDB)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
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
      })
    ]
  );
}
