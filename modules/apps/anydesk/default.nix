{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.anydesk;
  isLinux = lib.hasSuffix "-linux" system;
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
