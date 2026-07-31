{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.cake-wallet;
  inherit (constants) isDarwin isLinux;

  appId = "com.cakewallet.CakeWallet";
  appStoreId = 1334702542;
  version = "6.1.2";
  flatpakUrl = "https://github.com/cake-tech/cake_wallet/releases/download/v${version}/Cake_Wallet_v${version}_Linux.flatpak";
  flatpakBundle = pkgs.fetchurl {
    url = flatpakUrl;
    hash = "sha256-w0YqBEbGqOZK29DhmsIQgo7ruI/pl5iueOC6zpxrnK4=";
  };
in
{
  options.apps.cake-wallet = {
    enable = lib.mkEnableOption "Enable Cake Wallet";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        apps.flatpak = {
          enable = true;
          packages = [
            {
              inherit appId;
              bundle = "${flatpakBundle}";
              sha256 = "1blwdffcxfp0g2p9i5z9iywfp3l22319mqfhvd5fda668q22lin3";
            }
          ];
        };
      })

      (lib.optionalAttrs isDarwin {
        homebrew.masApps = {
          "Cake Wallet" = appStoreId;
        };
      })
    ]
  );
}
