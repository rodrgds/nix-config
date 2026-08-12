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
  edgeLinux = pkgs.microsoft-edge.override {
    # Hyprland does not provide server-side titlebars, so native Ozone/Wayland
    # gives Edge a second client-side header above its tab strip. Keep this one
    # application on XWayland for the compact single-header layout it had in i3.
    commandLineArgs = "--ozone-platform=x11";
  };
in
{
  options.apps.microsoft-edge = {
    enable = lib.mkEnableOption "Enable Microsoft Edge";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs (only if on Linux)
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [
          edgeLinux
          # for PWAs to work
          (pkgs.runCommand "microsoft-edge-stable-alias" { } ''
            mkdir -p $out/bin
            ln -s ${edgeLinux}/bin/microsoft-edge $out/bin/microsoft-edge-stable
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
