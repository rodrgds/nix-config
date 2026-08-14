{
  kdePackages,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "kde-breeze-cursors";
  inherit (kdePackages.breeze) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    cp -r \
      ${kdePackages.breeze}/share/icons/breeze_cursors \
      $out/share/icons/breeze_cursors

    runHook postInstall
  '';

  meta = {
    description = "KDE Breeze dark cursor theme";
    homepage = "https://invent.kde.org/plasma/breeze";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
  };
}
