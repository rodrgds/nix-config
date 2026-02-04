# Apps modules - flat structure, no categories
{ ... }:
{
  imports = [
    # Terminal & Shell
    ./ghostty
    ./alacritty
    ./fish
    ./starship

    # Development
    ./git
    ./opencode
    ./vscode
    ./arduino
    ./nodejs
    ./bun
    ./openjdk
    ./python
    ./android-studio
    ./android-sdk
    ./stripe-cli
    ./dbeaver

    # Desktop Environment
    ./i3
    ./bumblebee-status
    ./dunst
    ./redshift
    ./solaar
    ./xdg-portals
    ./gtk-theme
    ./cursor-theme
    ./rofi

    # Media
    ./obs
    ./mpv
    ./darktable
    ./gimp
    ./davinci-resolve
    ./auto-editor
    ./flameshot
    ./normcap
    ./charm-freeze
    ./stremio
    ./grayjay
    ./rescrobbled
    # Note: raycast is Darwin-only and in modules/darwin/apps

    # Gaming
    ./steam
    ./gamemode
    ./cs2
    ./prismlauncher
    ./lunarclient
    ./wine
    ./winetricks
    ./mangohud

    # Communication
    ./microsoft-edge
    ./ungoogled-chromium
    ./beeper
    ./vesktop
    ./telegram
    ./teamspeak
    ./thunderbird
    ./anydesk

    # Productivity
    ./obsidian
    ./qbittorrent
    ./vicinae

    # System
    ./core-packages
    ./neovim
    ./thunar
    ./syncthing
    ./synology-drive

    # Optional
    ./lamp
    ./laravel
    ./flatpak
  ];
}
