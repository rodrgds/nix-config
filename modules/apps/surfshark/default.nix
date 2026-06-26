{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.surfshark;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.surfshark = {
    enable = lib.mkEnableOption "Enable Surfshark";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        apps.flatpak = {
          enable = true;
          packages = [ "com.surfshark.Surfshark" ];
        };

        home-manager.users.${username} = _: {
          home.file.".local/share/applications/com.surfshark.Surfshark.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Surfshark
            Comment=Surfshark VPN
            Exec=flatpak run com.surfshark.Surfshark %U
            Icon=com.surfshark.Surfshark
            Terminal=false
            Categories=Network;Security;
            StartupNotify=true
            X-Flatpak=com.surfshark.Surfshark
          '';
        };
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "surfshark" ];
      })
    ]
  );
}
