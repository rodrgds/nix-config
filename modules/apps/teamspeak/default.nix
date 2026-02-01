{
  lib,
  config,
  pkgs,
  system,
  ...
}:
let
  cfg = config.apps.teamspeak;
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.teamspeak = {
    enable = lib.mkEnableOption "Enable TeamSpeak";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.teamspeak6-client ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "teamspeak" ];
      })
    ]
  );
}
