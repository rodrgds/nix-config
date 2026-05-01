{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.antigravity;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.antigravity = {
    enable = lib.mkEnableOption "Antigravity - Google's AI-powered VSCode fork";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.antigravity-fhs ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "antigravity" ];
      })
    ]
  );
}
