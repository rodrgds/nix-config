# WizTree for macOS. Upstream ships only a signed, versioned dmg without an
# updater, so pinning it here costs nothing. Mount it with the host hdiutil
# and copy with ditto so the code signature survives (see packages/vicu).
{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation rec {
  pname = "wiztree";
  version = "1.00";

  src = fetchurl {
    url = "https://diskanalyzer.com/files/WizTreeMac_${lib.replaceStrings [ "." ] [ "_" ] version}.dmg";
    hash = "sha256-VXOVzF+8LDrN0+lINS7WTVPKnhHP8gRadLb+RqFe0Vw=";
  };

  dontFixup = true;

  unpackPhase = ''
    runHook preUnpack
    /usr/bin/hdiutil attach "$src" -nobrowse -readonly -mountpoint "$TMPDIR/wiztree-mnt"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    /usr/bin/ditto "$TMPDIR/wiztree-mnt/WizTreeMac.app" "$out/Applications/WizTreeMac.app"
    /usr/bin/hdiutil detach "$TMPDIR/wiztree-mnt" -force || true
    runHook postInstall
  '';

  meta = {
    description = "Fast disk space analyzer";
    homepage = "https://diskanalyzer.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
}
