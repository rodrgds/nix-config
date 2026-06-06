{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.core.docker;
in
{
  options.core.docker = {
    enable = lib.mkEnableOption "Enable Docker";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      package = pkgs.docker_29;
    };
  };
}
