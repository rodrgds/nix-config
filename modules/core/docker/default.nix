{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.core.docker;
  inherit (constants) isDarwin isLinux;
in
{
  options.core.docker = {
    enable = lib.mkEnableOption "Enable Docker";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        virtualisation.docker = {
          enable = true;
          package = pkgs.docker_29;
        };
      })

      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "docker-desktop" ];
      })
    ]
  );
}
