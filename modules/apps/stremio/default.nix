{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.stremio;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.stremio = {
    enable = lib.mkEnableOption "Enable Stremio";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Flatpak avoids rebuilding the Electron app as part of NixOS.
      (lib.optionalAttrs isLinux {
        apps.flatpak = {
          enable = true;
          packages = [ "com.stremio.Stremio" ];
        };

        home-manager.users.${username} = _: {
          home.file.".local/share/applications/com.stremio.Stremio.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Stremio
            Comment=Freedom to Stream
            Exec=flatpak run com.stremio.Stremio %U
            Icon=com.stremio.Stremio
            Terminal=false
            Categories=AudioVideo;Video;Player;TV;
            StartupNotify=true
            X-Flatpak=com.stremio.Stremio
          '';
        };
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "stremio" ];
      })
    ]
  );
}
