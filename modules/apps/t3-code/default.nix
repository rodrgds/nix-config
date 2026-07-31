{
  config,
  lib,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.t3-code;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.t3-code = {
    enable = lib.mkEnableOption "Enable T3 Code";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.t3code ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "t3-code" ];
      })
    ]
  );
}
