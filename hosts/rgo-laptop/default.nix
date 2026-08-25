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
  secrets.enable = true;
  scripts.enable = true;
  apps.nix-tools.enable = true;
  apps.vicinae.enable = true;

  nixpkgs.config.allowUnfree = true;

  darwin.apps.aerospace.enable = true;
  darwin.apps.jankyborders.enable = true;
  # Instrument rail. It is lightweight and was not the cause of the CPU issue
  # (Syncthing was); if it ever needs to go, flip to false - the native macOS
  # menu bar returns. hideMenuBar controls the menu bar in the enabled state.
  darwin.apps.sketchybar.enable = true;
  darwin.apps.keyboard-layout.enable = true;

  networking.hostName = "rgo-laptop";

  apps.microsoft-edge.enable = false;
  apps.google-chrome.enable = true;
  apps.ghostty.enable = true;
  apps.bash.enable = true;
  apps.git.enable = true;
  apps.gh.enable = true;
  apps.ssh.enable = true;
  apps.neovim.enable = true;
  apps.starship.enable = true;

  apps.direnv.enable = true;
  apps.development-tools.enable = true;
  apps.graphviz.enable = true;
  apps.doxygen.enable = true;
  apps.golang.enable = true;
  apps.nodejs.enable = true;
  apps.pnpm.enable = true;
  apps.bun.enable = true;
  apps.python.enable = true;
  apps.php.enable = true;
  apps.cocoapods.enable = true;
  apps.m-cli.enable = true;
  apps.qbittorrent.enable = true;
  apps.vscode.enable = true;
  apps.cursor.enable = false;
  apps.antigravity.enable = false;
  apps.clion.enable = false;
  apps.virtualization.enable = true;
  apps.opencode.enable = true;
  apps.agents.enable = true;
  apps.pi.enable = true;
  apps.codex.enable = true;
  apps.claude.enable = true;
  apps.paseo = {
    enable = true;
    tailscale.enable = true;
  };
  apps.muse.enable = true;
  apps.t3-code.enable = true;
  apps.dbeaver.enable = true;
  apps.cap.enable = true;
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.zed.enable = true;
  apps.affinity.enable = false;
  apps.whop.enable = false;
  apps.maestro.enable = false;

  apps.telegram.enable = true;
  apps.teamspeak.enable = true;
  apps.beeper.enable = true;
  apps.surfshark.enable = true;

  apps.vesktop.enable = true;
  apps.obsidian.enable = true;
  apps.typst.enable = true;
  apps.flameshot.enable = true;

  apps.mpv.enable = true;
  apps.stremio.enable = true;
  apps.losslesscut.enable = false;
  apps.cake-wallet.enable = false;
  apps.ollama.enable = false;

  apps.syncthing.enable = true;
  apps.handy.enable = true;
  apps.ngrok.enable = true;

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
