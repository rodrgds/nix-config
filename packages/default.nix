# Package overlay
{ inputs }:
final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Home Manager's xresources module expects pkgs.xrdb, but on the stable set
  # the binary is namespaced under xorg.
  xrdb = prev.xorg.xrdb;

  stable = import inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Custom fonts
  bangers = prev.callPackage ./fonts/bangers { };
  bricolage-grotesque = prev.callPackage ./fonts/bricolage-grotesque { };
  climate-crisis = prev.callPackage ./fonts/climate-crisis { };

  # DaVinci Resolve customization
  davinci-resolve-studio =
    (import ./davinci-resolve {
      sourcePkgs = import inputs.nixpkgs-davinci {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })
      final
      prev;

  # Handy - Speech-to-text application
  inherit (inputs.handy.packages.${prev.stdenv.hostPlatform.system}) handy;

  # Disable direnv tests (they hang in the Nix sandbox)
  direnv = prev.direnv.overrideAttrs (_: {
    doCheck = false;
  });
}
