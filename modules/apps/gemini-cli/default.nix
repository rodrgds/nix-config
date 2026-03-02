{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.gemini-cli;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.gemini-cli = {
    enable = lib.mkEnableOption "Enable Gemini CLI";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.gemini-cli ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.packages = [ "gemini-cli" ];
      })
    ]
  );
}
