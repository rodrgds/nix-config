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
  darwin.apps.sketchybar.enable = true;

  networking.hostName = "rgo-laptop";

  apps.microsoft-edge.enable = true;
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
  apps.agent-skills.enable = true;
  apps.pi.enable = true;
  apps.worktrunk.enable = true;
  apps.codex.enable = true;
  apps.claude.enable = true;
  apps.paseo.enable = true;
  apps.muse.enable = true;
  apps.t3-code.enable = true;
  apps.whop.enable = true;
  apps.dbeaver.enable = true;
  apps.cap.enable = true;
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.affinity.enable = false;
  apps.zed.enable = true;

  apps.telegram.enable = true;
  apps.teamspeak.enable = true;
  apps.beeper.enable = true;
  apps.maestro.enable = false;
  apps.surfshark.enable = true;

  apps.vesktop.enable = true;
  apps.obsidian.enable = true;
  apps.typst.enable = true;
  apps.flameshot.enable = true;
  apps.cake-wallet.enable = false;

  apps.mpv.enable = true;
  apps.stremio.enable = true;
  apps.losslesscut.enable = true;

  apps.syncthing.enable = true;

  apps.handy.enable = true;

  apps.ngrok.enable = true;

  apps.ollama.enable = true;

  darwin.core.networking.tailscale.enable = true;
  core.docker.enable = true;
  core.downloads-cleanup.enable = true;
  core.cache-cleanup.enable = true;
  core.cache-cleanup.pnpm.projectRoots = [
    "/Users/rgo"
    "/Users/rgo/dev/openpost"
  ];
}
