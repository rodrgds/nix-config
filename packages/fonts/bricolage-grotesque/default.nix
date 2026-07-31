{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "bricolage-grotesque";
  version = "1.0";

  src = pkgs.fetchurl {
    url = "https://github.com/google/fonts/raw/main/ofl/bricolagegrotesque/BricolageGrotesque%5Bopsz%2Cwdth%2Cwght%5D.ttf";
    sha256 = "sha256-QT5zV4Cd3RL9gKlqijlt4OQBY41KzTyz43Uy8EcqxoI=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/BricolageGrotesque.ttf
    runHook postInstall
  '';
}
