{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.vesktop;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.vesktop = {
    enable = lib.mkEnableOption "Enable Vesktop";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vesktop ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "vesktop" ];
      })
    ]
  );
}
