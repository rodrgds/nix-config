# Package overlay
{ inputs }:
final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Custom fonts
  bangers = prev.callPackage ./fonts/bangers { };
  bricolage-grotesque = prev.callPackage ./fonts/bricolage-grotesque { };
  climate-crisis = prev.callPackage ./fonts/climate-crisis { };

  # Flexoki GTK theme
  flexoki-gtk = prev.callPackage ./flexoki-gtk { };

  # KDE Breeze cursor without the full Plasma styling closure.
  kde-breeze-cursors = prev.callPackage ./kde-breeze-cursors { };

  # Cap screen recorder (official Linux release).
  cap = prev.callPackage ./cap { };

  # Vicu desktop task manager (upstream AppImage on Linux, dmg on macOS).
  vicu = prev.callPackage ./vicu { };

  # WizTree disk analyzer (official macOS dmg).
  wiztree = prev.callPackage ./wiztree { };

  # Fast-moving tools come prebuilt from nixpkgs-unstable instead of being
  # compiled from their upstream flakes on every input update.
  inherit (final.unstable) devenv handy;
}
