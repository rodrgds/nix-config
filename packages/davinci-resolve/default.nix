{ sourcePkgs }:
final: prev:
let
  sourceZip =
    prev.runCommandLocal "davinci-resolve-studio-src.zip"
      rec {
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-5wt5bPJez3FiRzJrC8pzbfqa6BrYMsJJptXBC+ZwzlE=";

        impureEnvVars = prev.lib.fetchers.proxyImpureEnvVars;

        nativeBuildInputs = with prev; [
          cacert
          curl
          jq
        ];

        SSL_CERT_FILE = "${prev.cacert}/etc/ssl/certs/ca-bundle.crt";

        referId = "263d62f31cbb49e0868005059abcb0c9";
        downloadsUrl = "https://www.blackmagicdesign.com/api/support/us/downloads.json";
        siteUrl = "https://www.blackmagicdesign.com/api/register/us/download";
        product = "DaVinci Resolve Studio";
        version = "20.2.3";

        userAgent = builtins.concatStringsSep " " [
          "User-Agent: Mozilla/5.0 (X11; Linux ${prev.stdenv.hostPlatform.linuxArch})"
          "AppleWebKit/537.36 (KHTML, like Gecko)"
          "Chrome/77.0.3865.75"
          "Safari/537.36"
        ];

        reqJson = builtins.toJSON {
          firstname = "NixOS";
          lastname = "Linux";
          email = "someone@nixos.org";
          phone = "+31 71 452 5670";
          country = "nl";
          street = "-";
          state = "Province of Utrecht";
          city = "Utrecht";
          inherit product;
        };
      }
      ''
        set -euo pipefail

        download_id="$(
          curl --silent --show-error --compressed --http1.1 "$downloadsUrl" \
            | jq --raw-output '.downloads[] | .urls.Linux?[]? | select(.downloadTitle | test("^'"$product $version"'( Update)?$")) | .downloadId'
        )"
        echo "downloadid is $download_id"
        test -n "$download_id"

        resolve_url="$(
          curl \
            --silent \
            --show-error \
            --http1.1 \
            --header 'Host: www.blackmagicdesign.com' \
            --header 'Accept: application/json, text/plain, */*' \
            --header 'Origin: https://www.blackmagicdesign.com' \
            --header "$userAgent" \
            --header 'Content-Type: application/json;charset=UTF-8' \
            --header "Referer: https://www.blackmagicdesign.com/support/download/$referId/Linux" \
            --header 'Accept-Encoding: gzip, deflate, br' \
            --header 'Accept-Language: en-US,en;q=0.9' \
            --header 'Authority: www.blackmagicdesign.com' \
            --header 'Cookie: _ga=GA1.2.1849503966.1518103294; _gid=GA1.2.953840595.1518103294' \
            --data-ascii "$reqJson" \
            --compressed \
            "$siteUrl/$download_id"
        )"
        echo "resolveurl is $resolve_url"

        rm -f "$out"

        curl \
          --fail \
          --location \
          --show-error \
          --http1.1 \
          --retry 20 \
          --retry-all-errors \
          --retry-delay 5 \
          --continue-at - \
          --output "$out" \
          --header "Upgrade-Insecure-Requests: 1" \
          --header "$userAgent" \
          --header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
          --header "Accept-Language: en-US,en;q=0.9" \
          --compressed \
          "$resolve_url"
      '';

  ffmpeg-encoder-plugin = prev.stdenv.mkDerivation (finalAttrs: {
    pname = "ffmpeg-encoder-plugin";
    version = "1.1.0";

    src = prev.fetchFromGitHub {
      owner = "EdvinNilsson";
      repo = "ffmpeg_encoder_plugin";
      tag = "v${finalAttrs.version}";
      hash = "sha256-orghLIzz9rUnUwka9C71Z2nj+qxHuggrKNlYjLKswQw=";
    };

    nativeBuildInputs = with prev; [
      cmake
      ffmpeg-full
    ];

    buildInputs = with prev; [ ffmpeg ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp ffmpeg_encoder_plugin.dvcp $out/

      runHook postInstall
    '';
  });

  davinci = sourcePkgs.davinci-resolve-studio.passthru.davinci.overrideAttrs (old: {
    src = sourceZip;
    postFixup = ''
      ${old.postFixup}
      ${prev.perl}/bin/perl -pi -e 's/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\x74\x11\x48\x8B\x45\xC8\x8B/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\xEB\x11\x48\x8B\x45\xC8\x8B/' $out/bin/resolve

      ${prev.perl}/bin/perl -pi -e 's/\x74\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/\xEB\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/' $out/bin/resolve

      ${prev.perl}/bin/perl -pi -e 's/\x41\xb6\x01\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/\x41\xb6\x00\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/' $out/bin/resolve

      ${prev.perl}/bin/perl -pi -e 's/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\x74\x11\x48\x8B\x45\xC8\x8B/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\xEB\x11\x48\x8B\x45\xC8\x8B/g' $out/bin/resolve

      ${prev.perl}/bin/perl -pi -e 's/\x74\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/\xEB\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/g' $out/bin/resolve

      ${prev.perl}/bin/perl -pi -e 's/\x74\x11\xE8\x31\x25\x00\x00\x48\x89\xC7\xE8\x09\xBA\x02\x00\x84/\x75\x11\xE8\x31\x25\x00\x00\x48\x89\xC7\xE8\x09\xBA\x02\x00\x84/g' $out/bin/resolve

      mkdir -p $out/.license
      echo -e "LICENSE blackmagic davinciresolvestudio 999999 permanent uncounted\n  hostid=ANY issuer=CGP customer=CGP issued=28-dec-2023\n  akey=0000-0000-0000-0000 _ck=00 sig=\"00\"" > $out/.license/blackmagic.lic

      mkdir -p $out/IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64/
      cp ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp $out/IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64/
    '';
  });
in
prev.buildFHSEnv {
  inherit (davinci) pname version;

  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      aprutil
      bzip2
      davinci
      dbus
      expat
      fontconfig
      freetype
      glib
      libGL
      libGLU
      libarchive
      libcap
      librsvg
      libtool
      libuuid
      libxcrypt
      libxkbcommon
      nspr
      ocl-icd
      opencl-headers
      python3
      python3.pkgs.numpy
      udev
      xdg-utils
      xorg.libICE
      xorg.libSM
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXinerama
      xorg.libXrandr
      xorg.libXrender
      xorg.libXt
      xorg.libXtst
      xorg.libXxf86vm
      xorg.libxcb
      xorg.xcbutil
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      xorg.xkeyboardconfig
      zlib
    ];

  extraPreBwrapCmds = ''
    mkdir -p ~/.local/share/DaVinciResolve/license || exit 1
    mkdir -p ~/.local/share/DaVinciResolve/Extras || exit 1
    mkdir -p ~/.local/share/DaVinciResolve/configs || exit 1
    mkdir -p ~/.local/share/DaVinciResolve/logs || exit 1
  '';

  extraBwrapArgs = [
    ''--bind "$HOME"/.local/share/DaVinciResolve/license ${davinci}/.license''
    ''--bind "$HOME"/.local/share/DaVinciResolve/Extras ${davinci}/Extras''
    "--bind /run/opengl-driver/etc/OpenCL /etc/OpenCL"
  ];

  runScript = "${prev.bash}/bin/bash ${prev.writeText "davinci-wrapper" ''
    export QT_XKB_CONFIG_ROOT="${prev.xkeyboard_config}/share/X11/xkb"
    export QT_PLUGIN_PATH="${davinci}/libs/plugins:$QT_PLUGIN_PATH"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/lib32:${davinci}/libs
    unset QT_QPA_PLATFORM
    ${davinci}/bin/resolve
  ''}";

  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/128x128/apps
    ln -s ${davinci}/share/applications/*.desktop $out/share/applications/
    ln -s ${davinci}/graphics/DV_Resolve.png $out/share/icons/hicolor/128x128/apps/davinci-resolve-studio.png
  '';

  passthru = { inherit davinci; };
  inherit (sourcePkgs.davinci-resolve-studio) meta;
}
