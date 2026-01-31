# Package overlay
{ inputs }:
final: prev: {
  # Custom fonts
  bangers = prev.callPackage ./fonts/bangers { };
  bricolage-grotesque = prev.callPackage ./fonts/bricolage-grotesque { };

  # DaVinci Resolve customization
  davinci-resolve-studio = (import ./davinci-resolve) final prev;

  # Stable packages from nixpkgs-stable
  stable = import inputs.nixpkgs-stable {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
}
