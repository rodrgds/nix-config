{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "climate-crisis";
  version = "1.0";

  src = pkgs.fetchurl {
    url = "https://github.com/google/fonts/raw/main/ofl/climatecrisis/ClimateCrisis%5BYEAR%5D.ttf";
    sha256 = "sha256-SyUnn4DkIPnwnbuhPrFNC+q/oBPRf3S60ZzJ/fTVVSM=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/ClimateCrisis-Regular.ttf
    runHook postInstall
  '';
}
