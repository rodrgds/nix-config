{
  lib,
  config,
  pkgs,
  inputs,
  constants,
  ...
}:
let
  cfg = config.apps.affinity;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.affinity = {
    enable = lib.mkEnableOption "Enable Affinity";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [
          inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.v3
        ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "affinity"
        ];
      })
    ]
  );
}
