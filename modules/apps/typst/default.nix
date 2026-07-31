{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.typst;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.typst = {
    enable = lib.mkEnableOption "Enable Typst";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.typst ];
      })
      # Darwin: Install via Homebrew
      (lib.optionalAttrs isDarwin {
        homebrew.brews = [ "typst" ];
      })
    ]
  );
}
