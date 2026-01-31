{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.laravel;
in
{
  options.apps.laravel = {
    enable = lib.mkEnableOption "Enable Laravel development environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      php
      phpPackages.composer
    ];
  };
}
