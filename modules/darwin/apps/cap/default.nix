# Cap - Open-source AI coding assistant
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
    enable = lib.mkEnableOption "Enable Cap AI coding assistant";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "cap" ];
  };
}
