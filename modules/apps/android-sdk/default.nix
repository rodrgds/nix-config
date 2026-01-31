{
  lib,
  config,
  pkgs,
  inputs,
  username,
  ...
}:
let
  cfg = config.apps.android-sdk;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.apps.android-sdk = {
    enable = lib.mkEnableOption "Enable Android SDK";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      android-tools
      apksigner
      (inputs.android-nixpkgs.sdk.${system} (
        sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          build-tools-34-0-0
          platform-tools
          platforms-android-34
          emulator
        ]
      ))
    ];
  };
}
