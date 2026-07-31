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
  cfg = config.apps.vscode;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.vscode = {
    enable = lib.mkEnableOption "Enable VS Code";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.vscode ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "visual-studio-code" ];
      })
    ]
  );
}
