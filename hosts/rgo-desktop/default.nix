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

  scripts.enable = true;
  secrets.enable = true;

  apps.ghostty.enable = true;
  apps.bash.enable = true;
  apps.starship.enable = true;
  apps.git.enable = true;
  apps.gh.enable = true;
  apps.ssh.enable = true;
  apps.neovim.enable = true;
  apps.thunar.enable = true;

  apps.nix-tools.enable = true;

  apps.direnv.enable = true;
  apps.development-tools.enable = true;
  apps.graphviz.enable = true;
  apps.doxygen.enable = true;
  apps.golang.enable = true;
  apps.vscode.enable = true;
  apps.zed.enable = true;
  apps.nodejs.enable = true;
  apps.pnpm.enable = true;
  apps.bun.enable = true;
  apps.openjdk.enable = true;
  apps.python.enable = true;
  apps.php.enable = true;
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.dbeaver.enable = true;
  apps.cursor.enable = false;
  apps.antigravity.enable = false;
  apps.arduino.enable = false;
  apps.stripe-cli.enable = false;
  apps.laravel.enable = false;
  apps.affinity.enable = false;

  apps.hyprland.enable = true;
  apps.quickshell.enable = true;

  apps.i3.enable = false;
  apps.polybar.enable = false;
  apps.bumblebee-status.enable = false;
  apps.redshift.enable = false;
  apps.rofi.enable = false;

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
  apps.losslesscut.enable = false;
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

  apps.microsoft-edge.enable = true;
  apps.ungoogled-chromium.enable = true;
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
  apps.maestro.enable = false;
  apps.surfshark.enable = false;
  apps.cake-wallet.enable = false;

  apps.obsidian.enable = true;
  apps.qbittorrent.enable = true;
  apps.typst.enable = true;
  apps.qdirstat.enable = true;

  apps.core-packages.enable = true;
  apps.synology-drive.enable = true;
  apps.ngrok.enable = true;

  apps.opencode.enable = true;
  apps.agent-skills.enable = true;
  apps.pi.enable = true;
  apps.codex.enable = true;
  apps.claude.enable = true;
  apps.paseo = {
    enable = true;
    tailscale.enable = true;
  };
  apps.muse.enable = true;
  apps.t3-code.enable = true;

  apps.handy.enable = true;
  apps.vicinae.enable = true;
}
