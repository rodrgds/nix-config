{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.python;
in
{
  options.apps.python = {
    enable = lib.mkEnableOption "Enable Python";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.python3.withPackages (
        ps: with ps; [
          requests
        ]
      ))
    ];
  };
}
