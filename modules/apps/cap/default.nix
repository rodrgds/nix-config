{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.cap;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.cap = {
    enable = lib.mkEnableOption "Enable Cap screen recorder";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.cap ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "cap" ];
      })
    ]
  );
}
