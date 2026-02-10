# Host-specific configuration for rgo-desktop
{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./networking.nix
  ];

  # Enable core modules
  core.boot.enable = true;
  core.nix.enable = true;
  core.users.enable = true;
  core.locale.enable = true;
  core.environment.enable = true;
  core.security.enable = true;
  core.system.enable = true;
  core.audio.enable = true;
  core.fonts.enable = true;
  core.networking.enable = true;
  core.xserver.enable = true;
  core.nvidia.enable = true;
  core.peripherals.enable = true;
  apps.syncthing.enable = true;
  core.printing.enable = true;
  core.docker.enable = true;
  core.downloads-cleanup.enable = true;

  # Enable scripts
  scripts.enable = true;

  # Enable secrets
  secrets.enable = true;

  # Enable apps
  apps.ghostty.enable = true;
  apps.fish.enable = true;
  apps.starship.enable = true;
  apps.git.enable = true;
  apps.ssh.enable = true;
  apps.neovim.enable = true;
  apps.thunar.enable = true;

  # Development
  apps.vscode.enable = true;
  apps.arduino.enable = true;
  apps.nodejs.enable = true;
  apps.bun.enable = true;
  apps.openjdk.enable = true;
  apps.python.enable = true;
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.stripe-cli.enable = true;
  apps.dbeaver.enable = true;

  # Desktop
  apps.i3.enable = true;
  apps.bumblebee-status.enable = true;
  apps.dunst.enable = true;
  apps.redshift.enable = true;
  apps.solaar.enable = true;
  apps.xdg-portals.enable = true;
  apps.gtk-theme.enable = true;
  apps.cursor-theme.enable = true;
  apps.rofi.enable = false; # Disabled as requested

  # Media
  apps.obs.enable = true;
  apps.mpv.enable = true;
  apps.darktable.enable = true;
  apps.gimp.enable = true;
  apps.davinci-resolve.enable = true;
  apps.auto-editor.enable = true;
  apps.flameshot.enable = true;
  apps.normcap.enable = true;
  apps.charm-freeze.enable = true;
  apps.stremio.enable = true;
  apps.grayjay.enable = true;
  apps.rescrobbled.enable = true;

  # Gaming
  apps.steam.enable = true;
  apps.gamemode.enable = true;
  apps.cs2.enable = true;
  apps.prismlauncher.enable = true;
  apps.lunarclient.enable = true;
  apps.wine.enable = true;
  apps.winetricks.enable = true;
  apps.mangohud.enable = true;

  # Communication
  apps.microsoft-edge.enable = true;
  apps.ungoogled-chromium.enable = true;
  apps.beeper.enable = true;
  apps.vesktop.enable = true;
  apps.telegram.enable = true;
  apps.teamspeak.enable = true;
  apps.thunderbird.enable = true;
  apps.anydesk.enable = true;

  # Productivity
  apps.obsidian.enable = true;
  apps.qbittorrent.enable = true;

  # System
  apps.core-packages.enable = true;
  apps.synology-drive.enable = true;

  # Opencode
  apps.opencode.enable = true;

  # Vicinae
  apps.vicinae.enable = true;
}
