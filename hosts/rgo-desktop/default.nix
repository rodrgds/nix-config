{
  config,
  pkgs,
  username,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./networking.nix
  ];

  core.boot.enable = true;
  core.nix.enable = true;
  core.users.enable = true;
  core.locale.enable = true;
  core.security.enable = true;
  core.system.enable = true;
  # Updating a pinned local flake requires an intentional lock-file change.
  # The generic root-run auto-upgrade service cannot do that and also rejects
  # this user-owned Git checkout, so keep upgrades in the rebuild workflow.
  system.autoUpgrade.enable = lib.mkForce false;

  # Give systemd-oomd real reclaim headroom without consuming SSD space.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    priority = 100;
  };

  # Four GiB of historical journals is excessive on the 457 GiB root volume.
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=10G
    MaxRetentionSec=14day
  '';

  # Keep recent crash data for debugging without allowing a few large desktop
  # or game crashes to consume multiple gigabytes indefinitely.
  systemd.coredump.settings.Coredump = {
    MaxUse = "1G";
    KeepFree = "20G";
    ExternalSizeMax = "512M";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/coredump 0755 root root 3d"
  ];

  # The root NVMe has historical media/data-integrity errors and is beyond its
  # published TBW rating. Monitor both local drives so any further degradation
  # is recorded and surfaced in the desktop session.
  services.smartd = {
    enable = true;
    notifications.wall.enable = false;
    notifications.systembus-notify.enable = true;
  };
  core.audio.enable = true;
  core.fonts.enable = true;
  core.networking.enable = true;
  core.xserver.enable = true;
  core.nvidia.enable = true;
  core.peripherals.enable = true;

  networking.wireless.enable = lib.mkForce false;
  apps.syncthing.enable = true;
  core.printing.enable = true;
  core.docker.enable = true;
  apps.virtualization.enable = true;
  core.downloads-cleanup.enable = true;
  core.cache-cleanup = {
    enable = true;
    goBuildCache.extraDirectories = [
      "/home/${username}/dev/openpost/.devenv/state/go-build"
    ];
    bun.extraDirectories = [
      "/home/${username}/dev/openpost/.devenv/state/bun-cache"
    ];
  };

  profiles.personalWorkstation.enable = true;
  profiles.development.enable = true;
  profiles.agentWorkstation.enable = true;

  # Dormant tools kept for intentional, temporary opt-in.
  apps.davinci-resolve.enable = false;
  apps.fish.enable = false;
  apps.lamp.enable = false;
  apps.lunarclient.enable = false;
  apps.nushell.enable = false;
  apps.zsh.enable = false;

  apps.thunar.enable = true;
  apps.cursor.enable = false;
  apps.arduino.enable = false;
  apps.affinity.enable = false;

  apps.hyprland.enable = true;
  apps.quickshell.enable = true;

  apps.dunst.enable = true;
  apps.solaar.enable = true;
  apps.xdg-portals.enable = true;
  apps.rescrobbled.enable = true;

  apps.gtk-theme.enable = true;
  apps.qt-theme.enable = true;
  apps.cursor-theme.enable = true;

  apps.obs.enable = true;
  apps.mpv.enable = true;
  apps.auto-editor.enable = true;
  apps.normcap.enable = true;
  apps.charm-freeze.enable = true;
  apps.stremio.enable = true;
  apps.grayjay.enable = true;

  apps.cap.enable = false;
  apps.darktable.enable = false;
  apps.gimp.enable = false;
  apps.flameshot.enable = false;
  apps.flatpak.installFlatseal = false;

  apps.steam.enable = true;
  apps.gamemode.enable = true;
  apps.cs2.enable = true;
  apps.prismlauncher.enable = true;
  apps.wine.enable = true;
  apps.winetricks.enable = true;
  apps.mangohud.enable = true;

  apps.playwright = {
    enable = true;
    browserPackage = pkgs.ungoogled-chromium;
  };
  apps.beeper.enable = true;
  apps.vesktop.enable = true;
  apps.telegram.enable = true;
  apps.thunderbird.enable = true;
  apps.anydesk.enable = true;

  apps.teamspeak.enable = false;
  apps.surfshark.enable = false;
  apps.cake-wallet.enable = false;

  apps.obsidian.enable = true;
  apps.qdirstat.enable = true;

  apps.synology-drive.enable = true;
}
