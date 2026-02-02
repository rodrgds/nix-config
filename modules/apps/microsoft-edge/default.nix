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
  cfg = config.apps.microsoft-edge;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.microsoft-edge = {
    enable = lib.mkEnableOption "Enable Microsoft Edge";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = with pkgs; [
          microsoft-edge
          (runCommand "microsoft-edge-stable-alias" { } ''
            mkdir -p $out/bin
            ln -s ${microsoft-edge}/bin/microsoft-edge $out/bin/microsoft-edge-stable
          '')
        ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "microsoft-edge" ];
      })
    ]
  );
}
