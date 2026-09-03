{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:

let
  version = "1.8.0";

  releaseAsset =
    name: hash:
    fetchurl {
      url = "https://github.com/rendyhd/Vicu/releases/download/v${version}/${name}";
      inherit hash;
    };

  meta = with lib; {
    description = "Personal desktop task manager powered by Vikunja";
    homepage = "https://github.com/rendyhd/Vicu";
    license = licenses.mit;
    mainProgram = "vicu";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };

  linuxPackage =
    { asset, hash }:
    appimageTools.wrapType2 {
      pname = "vicu";
      inherit version;
      src = releaseAsset asset hash;
      inherit meta;
    };

  # Upstream ships no Homebrew cask, only a signed/notarized arm64 dmg, and
  # the image is APFS (undmg handles HFS only) with signature material in
  # extended attributes (7-Zip extraction breaks the seal). Mount the image
  # with the host hdiutil and copy it with ditto so every xattr survives.
  # Darwin builds in this repo run unsandboxed, so host tools are available.
  darwinPackage = stdenv.mkDerivation {
    pname = "vicu";
    inherit version;
    src = releaseAsset "Vicu-${version}-arm64.dmg" "sha256-VgoCwRpqK0JZotQHMhXTd0SvG3dV/eBxpFP4jm5rue0=";

    dontFixup = true;

    unpackPhase = ''
      runHook preUnpack
      /usr/bin/hdiutil attach "$src" -nobrowse -readonly -mountpoint "$TMPDIR/vicu-mnt"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      /usr/bin/ditto "$TMPDIR/vicu-mnt/Vicu.app" "$out/Applications/Vicu.app"
      /usr/bin/hdiutil detach "$TMPDIR/vicu-mnt" -force || true
      ln -s "$out/Applications/Vicu.app/Contents/MacOS/Vicu" "$out/bin/vicu"
      runHook postInstall
    '';

    installCheckPhase = ''
      runHook preInstallCheck
      /usr/bin/codesign --verify --deep --strict "$out/Applications/Vicu.app"
      runHook postInstallCheck
    '';

    inherit meta;
  };
in
if stdenv.isLinux then
  linuxPackage (
    if stdenv.hostPlatform.system == "x86_64-linux" then
      {
        asset = "Vicu-${version}-x86_64.AppImage";
        hash = "sha256-66tw0y55S2lRp+Kh1s4HoTxQqk1tY4OiUpwV3KEbPO0=";
      }
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      {
        asset = "Vicu-${version}-arm64.AppImage";
        hash = "sha256-iyw3WI79c8DkYhR9VE8FI3ohu/UWYdbpH/s/FulWL+M=";
      }
    else
      throw "vicu: unsupported Linux system ${stdenv.hostPlatform.system}"
  )
else if stdenv.hostPlatform.system == "aarch64-darwin" then
  darwinPackage
else
  throw "vicu: unsupported system ${stdenv.hostPlatform.system}"
