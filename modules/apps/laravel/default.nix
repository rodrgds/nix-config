{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.laravel;
  isLinux = lib.hasSuffix "-linux" system;
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
