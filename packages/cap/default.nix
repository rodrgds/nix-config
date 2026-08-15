{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  alsa-lib,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  libayatana-appindicator,
  libva,
  libsoup_3,
  openssl,
  pipewire,
  webkitgtk_4_1,
  libx11,
}:

stdenv.mkDerivation {
  pname = "cap";
  version = "0.5.9";

  src = fetchurl {
    url = "https://cdn.crabnebula.app/asset/01KZEFJYCGN6YJ32PQ7AX334RZ";
    hash = "sha256-4HzsmdG7nIYmAoZjcyIeLq4sOo7lljRqAUbTQcIkbMI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    cairo
    gdk-pixbuf
    glib
    gtk3
    libayatana-appindicator
    libva
    libsoup_3
    openssl
    pipewire
    stdenv.cc.cc.lib
    webkitgtk_4_1
    libx11
  ];

  # Cap loads AppIndicator with dlopen(), so autoPatchelf cannot discover it
  # from the executable's DT_NEEDED entries.
  runtimeDependencies = [ libayatana-appindicator ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/* "$out/"
    runHook postInstall
  '';

  # WebKitGTK's accelerated compositing produces a blank webview on the
  # NVIDIA/Wayland desktop. Keep the workaround local to Cap's wrapper.
  preFixup = ''
    gappsWrapperArgs+=(
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    if ! readelf -d "$out/bin/.Cap-wrapped" | grep -Fq '${libayatana-appindicator}/lib'; then
      echo "Cap's RUNPATH is missing its dynamically loaded AppIndicator library" >&2
      exit 1
    fi
    if ! grep -aFq -- "--set 'WEBKIT_DISABLE_COMPOSITING_MODE' '1'" "$out/bin/Cap"; then
      echo "Cap's wrapper does not disable WebKit compositing" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Beautiful screen recordings, owned by you";
    homepage = "https://cap.so";
    license = lib.licenses.agpl3Only;
    mainProgram = "Cap";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
