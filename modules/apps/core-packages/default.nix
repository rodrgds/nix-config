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
    enable = lib.mkEnableOption "Enable core system packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Essential command-line tools
      htop
      unzip
      zip
      wget
      curl
      gcc
      gnumake
      gnugrep
      tealdeer
      openssl
      cmake

      # System information and utilities
      scrot
      xdotool
      inxi
      pciutils
      dmidecode
      smartmontools
      mesa-demos
      xorg.xdpyinfo
      usbutils
      xclip
      dex
      zenity
      nfs-utils

      # Nix tools
      nixd
      nixfmt

      # Audio
      pulseaudioFull
      pavucontrol
      playerctl

      # Notifications & Desktop utilities
      libnotify
      feh
      polkit_gnome
      dconf
    ];
  };
}
