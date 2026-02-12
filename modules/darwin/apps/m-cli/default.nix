# m-cli - Swiss Army Knife for macOS
# Installed via Homebrew on Darwin
{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.m-cli;
in
{
  options.apps.m-cli = {
    enable = lib.mkEnableOption "Enable m-cli (Swiss Army Knife for macOS)";
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [ "m-cli" ];
  };
}
