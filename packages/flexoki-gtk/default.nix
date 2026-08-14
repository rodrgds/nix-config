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

    # GTK_THEME's optional `:dark` variant is not consistently honored by
    # GTK3 and GTK4 consumers. Expose the dark palette as its own theme whose
    # default stylesheet is dark, so every toolkit path resolves identically.
    cp -r $out/share/themes/flexoki $out/share/themes/flexoki-dark
    chmod -R u+w $out/share/themes/flexoki-dark
    for toolkit in gtk-3.0 gtk-4.0; do
      cp \
        $out/share/themes/flexoki-dark/$toolkit/gtk-dark.css \
        $out/share/themes/flexoki-dark/$toolkit/gtk.css
      mv \
        $out/share/themes/flexoki-dark/$toolkit/gtk.css \
        $out/share/themes/flexoki-dark/$toolkit/gtk-base.css
      cp ${./dark-overrides.css} \
        $out/share/themes/flexoki-dark/$toolkit/gtk.css
    done
    substituteInPlace $out/share/themes/flexoki-dark/index.theme \
      --replace-fail 'Name=flexoki' 'Name=flexoki-dark' \
      --replace-fail 'GtkTheme=flexoki' 'GtkTheme=flexoki-dark'
  '';
}
