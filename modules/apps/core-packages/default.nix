{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.core-packages;
in
{
  options.apps.core-packages = {
    enable = lib.mkEnableOption "Enable core-packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # Essential command-line tools
      pkgs.htop
      pkgs.unzip
      pkgs.zip
      pkgs.wget
      pkgs.curl
      pkgs.gcc
      pkgs.gnumake
      pkgs.gnugrep
      pkgs.tealdeer
      pkgs.openssl
      pkgs.cmake

      # System information and utilities
      pkgs.scrot
      pkgs.xdotool
      pkgs.inxi
      pkgs.pciutils
      pkgs.dmidecode
      pkgs.smartmontools
      pkgs.mesa-demos
      pkgs.xorg.xdpyinfo
      pkgs.usbutils
      pkgs.xclip
      pkgs.dex
      pkgs.zenity
      pkgs.nfs-utils

      # Nix tools
      pkgs.nixd
      pkgs.nixfmt

      # Audio
      pkgs.pulseaudioFull
      pkgs.pavucontrol
      pkgs.playerctl

      # Notifications & Desktop utilities
      pkgs.libnotify
      pkgs.feh
      pkgs.polkit_gnome
      pkgs.dconf
    ];
  };
}
