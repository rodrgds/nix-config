{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.auto-editor;
  isLinux = lib.hasSuffix "-linux" system;
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
