{
  fetchFromGitHub,
  fetchFromGitLab,
  lib,
  stdenvNoCC,
}:
let
  hyprcursorSource = fetchFromGitLab {
    owner = "Pummelfisch";
    repo = "future-cyan-hyprcursor";
    rev = "cf4126d17f4520aceb688d8a60daca4a1f0b9e80";
    hash = "sha256-a7LdP2VH0UlMPwW9vbBolOuPQMJa0WNpmJfLLv3JZ4g=";
  };

  xcursorSource = fetchFromGitHub {
    owner = "yeyushengfan258";
    repo = "Future-cursors";
    rev = "587c14d2f5bd2dc34095a4efbb1a729eb72a1d36";
    hash = "sha256-ziEgMasNVhfzqeURjYJK1l5BeIHk8GK6C4ONHQR7FyY=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "future-cyan-cursors";
  version = "unstable-2024-07-18";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/icons/Future-Cyan"
    mkdir -p "$themeDir"
    cp -r ${xcursorSource}/dist/. "$themeDir/"
    cp -r ${hyprcursorSource}/Future-Cyan-Hyprcursor_Theme/hyprcursors "$themeDir/"
    cp ${hyprcursorSource}/Future-Cyan-Hyprcursor_Theme/manifest.hl "$themeDir/"

    runHook postInstall
  '';

  meta = {
    description = "Future Cyan cursor theme for Hyprcursor and XCursor";
    homepage = "https://gitlab.com/Pummelfisch/future-cyan-hyprcursor";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
