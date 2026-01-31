{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.microsoft-edge;
in
{
  options.apps.microsoft-edge = {
    enable = lib.mkEnableOption "Enable Microsoft Edge";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      microsoft-edge
      (runCommand "microsoft-edge-stable-alias" { } ''
        mkdir -p $out/bin
        ln -s ${microsoft-edge}/bin/microsoft-edge $out/bin/microsoft-edge-stable
      '')
    ];
  };
}
