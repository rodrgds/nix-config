{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.anydesk;
in
{
  options.apps.anydesk = {
    enable = lib.mkEnableOption "Enable AnyDesk";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.anydesk ];
  };
}
