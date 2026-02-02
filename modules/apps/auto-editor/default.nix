{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.auto-editor;
  inherit (constants) isLinux;
in
{
  options.apps.auto-editor = {
    enable = lib.mkEnableOption "Enable auto-editor";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.auto-editor ];
      })
    ]
  );
}
