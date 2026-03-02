{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.development-tools;
in
{
  options.apps.development-tools = {
    enable = lib.mkEnableOption "Enable development tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nil # Nix language server
    ];
  };
}
