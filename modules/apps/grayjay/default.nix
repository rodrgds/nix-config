{
  lib,
  config,
  constants,
  username,
  ...
}:
let
  cfg = config.apps.grayjay;
  inherit (constants) isLinux;
in
{
  options.apps.grayjay = {
    enable = lib.mkEnableOption "Enable Grayjay";
  };

  # Go to Settings -> Synchronization -> Renay Enable (turn OFF)
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        apps.flatpak = {
          enable = true;
          packages = [ "app.grayjay.Grayjay" ];
          overrides."app.grayjay.Grayjay".Environment = {
            # relay.grayjay.app currently resolves IPv6 first on this host, but
            # the IPv6 relay connection times out while IPv4 succeeds.
            DOTNET_SYSTEM_NET_DISABLEIPV6 = "1";
          };
        };

        home-manager.users.${username} = _: {
          home.file.".local/share/applications/app.grayjay.Grayjay.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Grayjay
            Comment=Follow creators, not platforms
            Exec=flatpak run app.grayjay.Grayjay %U
            Icon=app.grayjay.Grayjay
            Terminal=false
            Categories=AudioVideo;Video;Network;
            StartupWMClass=Grayjay
            X-Flatpak=app.grayjay.Grayjay
          '';
        };
      })
    ]
  );
}
