# Apps modules - flat structure, no categories
{ ... }:
{
  imports = [
    # Terminal & Shell
    ./ghostty
    ./alacritty
    ./fish
    ./nushell
    ./starship
    ./ssh

    # Development
    ./git
    ./gh
    ./opencode
    ./gemini-cli
    ./development-tools
    ./vscode
    ./zed
    ./antigravity
    ./arduino
    ./nodejs
    ./bun
    ./openjdk
    ./python
    ./android-studio
    ./android-sdk
    ./clion
    ./virtualization
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
    ./maestro

    # Productivity
    ./obsidian
    ./qbittorrent
    ./vicinae
    ./typst

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

    # Handy
    ./handy
  ];
}
