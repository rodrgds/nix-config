{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.lamp;
  inherit (constants) isLinux;
in
{
  options.apps.lamp = {
    enable = lib.mkEnableOption "Enable LAMP";
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
