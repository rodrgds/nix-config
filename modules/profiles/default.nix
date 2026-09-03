{
  config,
  constants,
  devenvPkg,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.profiles;
  inherit (constants) isDarwin isLinux;

  personalWorkstationPackages = lib.optionals isLinux [
    pkgs.htop
    pkgs.unzip
    pkgs.zip
    pkgs.wget
    pkgs.tealdeer
    pkgs.openssl
    pkgs.inxi
    pkgs.pciutils
    pkgs.dmidecode
    pkgs.smartmontools
    pkgs.mesa-demos
    pkgs.usbutils
    pkgs.zenity
    pkgs.pavucontrol
    pkgs.playerctl
    pkgs.libnotify
  ];

  developmentPackages = [
    pkgs.sqlite
    devenvPkg
  ];
in
{
  options.profiles = {
    personalWorkstation.enable = lib.mkEnableOption "shared personal workstation defaults";
    development.enable = lib.mkEnableOption "shared development workstation defaults";
    agentWorkstation.enable = lib.mkEnableOption "shared agent workstation defaults";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.personalWorkstation.enable {
      scripts.enable = lib.mkDefault true;
      secrets.enable = lib.mkDefault true;

      apps.google-chrome.enable = lib.mkDefault true;
      apps.ghostty.enable = lib.mkDefault true;
      apps.bash.enable = lib.mkDefault true;
      apps.starship.enable = lib.mkDefault true;
      apps.git.enable = lib.mkDefault true;
      apps.gh.enable = lib.mkDefault true;
      apps.ssh.enable = lib.mkDefault true;
      apps.neovim.enable = lib.mkDefault true;
      apps.qbittorrent.enable = lib.mkDefault true;
      apps.syncthing.enable = lib.mkDefault true;
      apps.typst.enable = lib.mkDefault true;
      apps.ngrok.enable = lib.mkDefault true;
      apps.handy.enable = lib.mkDefault true;
      apps.vicinae.enable = lib.mkDefault true;

      environment.systemPackages = personalWorkstationPackages;
    })
    (lib.mkIf cfg.development.enable {
      apps.direnv.enable = lib.mkDefault true;
      apps.nix-tools.enable = lib.mkDefault true;
      apps.vscode.enable = lib.mkDefault true;
      apps.zed.enable = lib.mkDefault true;
      apps.dbeaver.enable = lib.mkDefault true;
      apps.python.enable = lib.mkDefault true;
      apps.virtualization.enable = lib.mkDefault true;
      apps.android-studio.enable = lib.mkDefault true;
      apps.android-sdk.enable = lib.mkDefault true;

      apps.javascript-toolchain = {
        enable = lib.mkDefault true;
        bun.enable = lib.mkDefault true;
      };

      environment.systemPackages = developmentPackages;
    })

    (lib.mkIf cfg.agentWorkstation.enable {
      apps.opencode.enable = lib.mkDefault true;
      apps.agents.enable = lib.mkDefault true;
      apps.pi.enable = lib.mkDefault true;
      apps.codex.enable = lib.mkDefault true;
      apps.claude.enable = lib.mkDefault true;
      apps.muse.enable = lib.mkDefault true;
      apps.t3-code.enable = lib.mkDefault true;
      apps.hermes-desktop.enable = lib.mkDefault (!isDarwin);
      apps.worktrunk.enable = lib.mkDefault true;
    })

    (lib.optionalAttrs isDarwin (
      lib.mkIf cfg.personalWorkstation.enable {
        darwin.apps.mCli.enable = lib.mkDefault true;
      }
    ))

    (lib.optionalAttrs isDarwin (
      lib.mkIf cfg.development.enable {
        darwin.apps.cocoapods.enable = lib.mkDefault true;
      }
    ))
  ];
}
