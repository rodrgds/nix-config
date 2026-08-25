{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./system.nix
  ];

  darwin.core.system.enable = true;
  darwin.core.networking.enable = true;
  darwin.core.networking.nas.enable = true;
  darwin.core.fonts.enable = true;
  darwin.core.homebrew.enable = true;
  darwin.core.karabiner.enable = true;

  core.nix.enable = true;
  profiles.personalWorkstation.enable = true;
  profiles.development.enable = true;
  profiles.agentWorkstation.enable = true;

  # Dormant shells kept for intentional, temporary opt-in.
  apps.fish.enable = false;
  apps.nushell.enable = false;
  apps.zsh.enable = false;

  nixpkgs.config.allowUnfree = true;

  darwin.apps.aerospace.enable = true;
  darwin.apps.jankyborders.enable = true;
  # Instrument rail. It is lightweight and was not the cause of the CPU issue
  # (Syncthing was); if it ever needs to go, flip to false - the native macOS
  # menu bar returns. hideMenuBar controls the menu bar in the enabled state.
  darwin.apps.sketchybar.enable = true;
  darwin.apps.keyboard-layout.enable = true;

  networking.hostName = "rgo-laptop";

  apps.cursor.enable = false;
  apps.clion.enable = false;
  apps.cap.enable = true;
  apps.affinity.enable = false;

  apps.telegram.enable = true;
  apps.teamspeak.enable = true;
  apps.beeper.enable = true;
  apps.surfshark.enable = true;

  apps.vesktop.enable = true;
  apps.obsidian.enable = true;
  apps.flameshot.enable = true;

  apps.mpv.enable = true;
  apps.stremio.enable = true;
  apps.cake-wallet.enable = false;
  apps.ollama.enable = true;

  darwin.core.networking.tailscale.enable = true;
  core.docker.enable = true;
  core.downloads-cleanup.enable = true;
  core.cache-cleanup = {
    enable = true;
    goBuildCache.extraDirectories = [
      "/Users/rgo/dev/openpost/.devenv/state/go-build"
    ];
    bun.extraDirectories = [
      "/Users/rgo/dev/openpost/.devenv/state/bun-cache"
    ];
  };
}
