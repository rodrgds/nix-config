# Cap - Screen recorder for macOS
# Installed via Homebrew
{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.cap;
in
{
  options.apps.cap = {
    enable = lib.mkEnableOption "Enable Cap";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "cap" ];
  };
}
