{
  lib,
  config,
  pkgs,
  inputs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.android-sdk;
  hostSystem = pkgs.stdenv.hostPlatform.system;
  inherit (constants) isLinux;
in
{
  options.apps.android-sdk = {
    enable = lib.mkEnableOption "Enable Android SDK";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = with pkgs; [
          android-tools
          apksigner
          (inputs.android-nixpkgs.sdk.${hostSystem} (
            sdkPkgs: with sdkPkgs; [
              cmdline-tools-latest
              build-tools-34-0-0
              platform-tools
              platforms-android-34
              emulator
            ]
          ))
        ];
      })
    ]
  );
}
