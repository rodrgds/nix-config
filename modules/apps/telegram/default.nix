{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.telegram;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.telegram = {
    enable = lib.mkEnableOption "Enable Telegram";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.telegram-desktop ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "telegram" ];
      })
    ]
  );
}
