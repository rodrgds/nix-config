{
  lib,
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

  apps.virtualization.enable = false;
  # iOS work uses Xcode and its simulators; Android lives on rgo-desktop.
  apps.android-studio.enable = false;
  apps.android-sdk.enable = false;

  # Dormant tools kept for intentional, temporary opt-in.
  apps.fish.enable = false;
  apps.nushell.enable = false;
  apps.ollama.enable = false;
  apps.syncthing.enable = false;
  apps.vscode.enable = false;
  apps.zsh.enable = false;

  nixpkgs.config.allowUnfree = true;

  apps.brave.enable = true;

  darwin.apps.aerospace.enable = true;
  darwin.apps.lightweight-borders.enable = true;
  darwin.apps.sketchybar.enable = false;
  darwin.apps.keepingyouawake.enable = true;
  darwin.apps.stats.enable = true;
  darwin.apps.keyboard-layout.enable = true;

  networking.hostName = "rgo-laptop";

  apps.cursor.enable = false;
  apps.clion.enable = false;
  apps.cap.enable = true;

  apps.telegram.enable = true;
  apps.teamspeak.enable = true;
  apps.beeper.enable = true;
  apps.surfshark.enable = true;

  apps.vesktop.enable = true;
  apps.obsidian.enable = true;
  apps.screenshot-tools.enable = true;
  apps.vicu.enable = true;
  apps.wiztree.enable = true;

  apps.mpv.enable = true;
  apps.blender.enable = true;
  apps.blender.mcp.enable = true;
  apps.cake-wallet.enable = false;

  darwin.core.networking.tailscale.enable = true;
  core.docker.enable = true;
  core.docker.desktopMemoryMiB = 4096;
  core.downloads-cleanup.enable = true;
  core.cache-cleanup = {
    enable = true;
    # Automatic rescue is separate from the rebuild wizard's space preflight.
    pressureFreeGiB = 16;
    autoPressure.recoveryFreeGiB = 24;
    userCache.boundedDirectories = [
      {
        # Turbo's local cache never evicts on its own.
        name = "OpenPost Turbo";
        directory = "/Users/rgo/.cache/openpost/turbo";
        processPattern = "(^|/)(turbo|bun|node|npm|pnpm)( |$)";
      }
    ];
  };
}
