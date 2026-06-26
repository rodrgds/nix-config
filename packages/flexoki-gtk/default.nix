{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "flexoki-gtk";
  version = "2.0";

  src = fetchFromGitHub {
    owner = "kepano";
    repo = "flexoki";
    rev = "8d723bac4a9ac46adfdf99d42155286977aac72a";
    hash = "sha256-IxnvoZ9hGEvwq/PBbHTL5L2a2kxMSXSINIfd5Dg9ttA=";
  };

  installPhase = ''
    mkdir -p $out/share/themes/flexoki
    cp -r $src/gtk/* $out/share/themes/flexoki/
    rm -f $out/share/themes/flexoki/README.md
  '';
}
