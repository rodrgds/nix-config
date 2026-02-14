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
    home-manager.users.${username} = {
      home.packages = with pkgs; [
        nil # Nix language server
      ];
    };
  };
}
