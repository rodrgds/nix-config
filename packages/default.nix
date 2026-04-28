# Package overlay
{ inputs }:
final: prev: {
  # Custom fonts
  bangers = prev.callPackage ./fonts/bangers { };
  bricolage-grotesque = prev.callPackage ./fonts/bricolage-grotesque { };
  climate-crisis = prev.callPackage ./fonts/climate-crisis { };

  # DaVinci Resolve customization
  davinci-resolve-studio = (import ./davinci-resolve) final prev;

  # Handy - Speech-to-text application
  inherit (inputs.handy.packages.${prev.stdenv.hostPlatform.system}) handy;

  # Disable direnv tests (they hang in the Nix sandbox)
  direnv = prev.direnv.overrideAttrs (_: {
    doCheck = false;
  });

  # Stable packages from nixpkgs-stable
  stable = import inputs.nixpkgs-stable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
