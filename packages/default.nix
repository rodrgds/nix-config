# Package overlay
{ inputs }:
final: prev:
let
  affinityOverlay = inputs.affinity-nix.overlays.default final prev;
in
affinityOverlay
// {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  stable = import inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Custom fonts
  bangers = prev.callPackage ./fonts/bangers { };
  bricolage-grotesque = prev.callPackage ./fonts/bricolage-grotesque { };
  climate-crisis = prev.callPackage ./fonts/climate-crisis { };

  # Flexoki GTK theme
  flexoki-gtk = prev.callPackage ./flexoki-gtk { };

  # Matching Hyprcursor and XCursor variants for the desktop.
  future-cyan-cursors = prev.callPackage ./future-cyan-cursors { };

  # Polybar with i3 support (not enabled by default in nixpkgs)
  polybar = prev.polybar.override { i3Support = true; };

  # Handy - Speech-to-text application
  inherit (inputs.handy.packages.${prev.stdenv.hostPlatform.system}) handy;

  # Disable direnv tests (they hang in the Nix sandbox)
  direnv = prev.direnv.overrideAttrs (_: {
    doCheck = false;
  });

  # mpv currently fails Darwin install-time version probing even though the
  # build itself succeeds, so skip that broken post-install check on macOS.
  mpv-unwrapped = prev.mpv-unwrapped.overrideAttrs (
    _:
    if prev.stdenv.hostPlatform.isDarwin then
      {
        doInstallCheck = false;
        installCheckPhase = ":";
      }
    else
      { }
  );
}
