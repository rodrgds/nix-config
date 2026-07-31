{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "bangers";
  version = "1.0";

  src = pkgs.fetchurl {
    url = "https://github.com/google/fonts/raw/main/ofl/bangers/Bangers-Regular.ttf";
    sha256 = "sha256-QWCnMR3pNCZ0zOkWDN6fy7MPSBkDl9hv8bcLRVr2WCQ=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/Bangers-Regular.ttf
    runHook postInstall
  '';
}
