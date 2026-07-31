{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.anydesk;
  inherit (constants) isLinux;
in
{
  options.apps.anydesk = {
    enable = lib.mkEnableOption "Enable AnyDesk";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.anydesk ];
      })
    ]
  );
}
