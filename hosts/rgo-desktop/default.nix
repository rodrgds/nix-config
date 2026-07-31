{
  config,
  pkgs,
  username,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.vicinae.nixosModules.default
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

  # The root NVMe has historical media/data-integrity errors and is beyond its
  # published TBW rating. Monitor both local drives so any further degradation
  # is recorded and surfaced in the desktop session.
  services.smartd = {
    enable = true;
    notifications.wall.enable = false;
    notifications.x11.enable = true;
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
  apps.cursor.enable = false;
  apps.antigravity.enable = false;
  apps.arduino.enable = true;
  apps.nodejs.enable = true;
  apps.pnpm.enable = true;
  apps.bun.enable = true;
  apps.openjdk.enable = true;
  apps.python.enable = true;
  apps.php.enable = true;
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.stripe-cli.enable = true;
  apps.dbeaver.enable = true;
  apps.laravel.enable = true;
  apps.affinity.enable = false;

  apps.i3.enable = true;
  # apps.bumblebee-status.enable = true;
  apps.polybar.enable = true;
  apps.dunst.enable = true;
  apps.redshift.enable = true;
  apps.solaar.enable = true;
  apps.xdg-portals.enable = true;
  apps.gtk-theme.enable = true;
  apps.cursor-theme.enable = true;
  apps.rofi.enable = false;

  apps.obs.enable = true;
  apps.mpv.enable = true;
  apps.darktable.enable = true;
  apps.gimp.enable = true;
  apps.davinci-resolve.enable = true;
  apps.auto-editor.enable = true;
  apps.losslesscut.enable = true;
  apps.flameshot.enable = true;
  apps.normcap.enable = true;
  apps.charm-freeze.enable = true;
  apps.stremio.enable = true;
  apps.grayjay.enable = true;
  apps.rescrobbled.enable = true;

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
  apps.teamspeak.enable = true;
  apps.thunderbird.enable = true;
  apps.anydesk.enable = true;
  apps.maestro.enable = true;
  apps.surfshark.enable = true;

  apps.obsidian.enable = true;
  apps.qbittorrent.enable = true;
  apps.typst.enable = true;
  apps.qdirstat.enable = true;
  apps.cake-wallet.enable = false;

  apps.core-packages.enable = true;
  apps.synology-drive.enable = true;
  apps.ngrok.enable = true;

  apps.opencode.enable = true;
  apps.pi.enable = true;
  apps.codex.enable = true;
  apps.claude.enable = true;
  apps.t3-code.enable = true;

  apps.handy.enable = true;

  apps.vicinae.enable = true;
}
