{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.laravel;
  inherit (constants) isLinux;
in
{
  options.apps.laravel = {
    enable = lib.mkEnableOption "Enable Laravel development environment";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = with pkgs; [
          php
          phpPackages.composer
        ];
      })
    ]
  );
}
