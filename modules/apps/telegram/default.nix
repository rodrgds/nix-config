{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.telegram;
in
{
  options.apps.telegram = {
    enable = lib.mkEnableOption "Enable Telegram";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.telegram-desktop ];
  };
}
