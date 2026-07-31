{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.graphviz;
in
{
  options.apps.graphviz = {
    enable = lib.mkEnableOption "Enable Graphviz";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.graphviz
    ];
  };
}
