{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.pnpm;
  inherit (constants) isDarwin;
in
{
  options.apps.pnpm = {
    enable = lib.mkEnableOption "Enable pnpm";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.pnpm ];

    home-manager.users.${username} = lib.mkIf isDarwin {
      home.packages = [ pkgs.pnpm ];
    };
  };
}
