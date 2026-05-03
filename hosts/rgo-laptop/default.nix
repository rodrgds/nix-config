# MacBook Pro M4 (aarch64-darwin) configuration - rgo-laptop
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

  # Enable Darwin core modules
  darwin.core.system.enable = true;
  darwin.core.networking.enable = true;
  darwin.core.fonts.enable = true;
  darwin.core.homebrew.enable = true;
  darwin.core.karabiner.enable = true;

  # Enable Nix configuration (cross-platform)
  core.nix.enable = true;

  # Enable secrets management with sops-nix
  secrets.enable = true;

  # Enable scripts (rebuild command and aliases)
  scripts.enable = true;

  # Nix tooling
  apps.nix-tools.enable = true;

  # Allow unfree packages on macOS
  nixpkgs.config.allowUnfree = true;

  # Enable Darwin apps (Aerospace window manager + JankyBorders)
  darwin.apps.aerospace.enable = true;
  darwin.apps.jankyborders.enable = true;

  # Hostname
  networking.hostName = "rgo-laptop";

  # ============================================
  # ENABLE ALL YOUR APPS
  # These modules automatically handle both platforms:
  # - On Linux: Install via nixpkgs
  # - On Darwin: Install via Homebrew (if not in nixpkgs)
  # ============================================

  # Browsers
  apps.microsoft-edge.enable = true; # Edge browser

  # Terminal & Shell
  apps.ghostty.enable = true; # Config via home-manager
  apps.bash.enable = true; # Gruvbox theme, completion, fzf integration
  apps.git.enable = true; # Git config, osxkeychain credential helper
  apps.gh.enable = true; # GitHub CLI
  apps.ssh.enable = true; # SSH client configuration
  apps.neovim.enable = true; # Neovim with EDITOR env var
  apps.starship.enable = true; # Starship prompt with Bash integration

  # Development
  apps.direnv.enable = true;
  apps.development-tools.enable = true;
  apps.graphviz.enable = true;
  apps.doxygen.enable = true;
  apps.golang.enable = true;
  apps.nodejs.enable = true; # Node.js with npm config
  apps.bun.enable = true; # Bun JavaScript runtime
  apps.python.enable = true; # Python with pip config
  apps.php.enable = true; # PHP development (Homebrew on Darwin)
  apps.cocoapods.enable = true; # CocoaPods dependency manager (Homebrew on Darwin)
  apps.m-cli.enable = true; # m-cli Swiss Army Knife for macOS (Homebrew on Darwin)
  apps.qbittorrent.enable = true;
  apps.vscode.enable = true; # VSCode: (unfree, available in nixpkgs)
  apps.antigravity.enable = true; # Antigravity: Google's AI-powered VSCode fork
  apps.clion.enable = true; # CLion IDE (nixpkgs on Linux, Homebrew on Darwin)
  apps.virtualization.enable = true; # QEMU + UTM (Darwin) / VirtualBox (Linux)
  apps.opencode.enable = true; # CLI tool with gruvbox theme
  apps.pi.enable = true;
  apps.gemini-cli.enable = true;
  apps.codex.enable = true;
  apps.claude.enable = true;
  apps.dbeaver.enable = true; # DBeaver database tool (available in nixpkgs)
  apps.cap.enable = true; # Cap screen recorder
  apps.android-studio.enable = true;
  apps.android-sdk.enable = true;
  apps.affinity.enable = true;
  apps.zed.enable = true; # Zed editor (Homebrew on Darwin)

  # Communication
  apps.telegram.enable = true; # Telegram Desktop (available in nixpkgs)
  apps.teamspeak.enable = true; # TeamSpeak (nixpkgs on Linux, Homebrew cask on Darwin)
  apps.beeper.enable = true; # Beeper messaging
  apps.maestro.enable = true; # Maestro mobile automation tool

  # Productivity
  apps.obsidian.enable = true; # Obsidian (unfree, available in nixpkgs)
  apps.typst.enable = true; # Typst typesetting system (Homebrew on Darwin)
  # apps.raycast.enable = true; # Launcher (Homebrew on Darwin)
  apps.flameshot.enable = true; # Screenshots (Homebrew on Darwin)

  # Media
  apps.mpv.enable = true; # MPV with custom Lua script for camera toggle
  apps.stremio.enable = true; # Stremio (nixpkgs on Linux, Homebrew on Darwin)

  # System
  apps.syncthing.enable = true; # File sync (systemd on NixOS, Homebrew on Darwin)

  # Handy
  apps.handy.enable = true; # Speech-to-text

  # Tunnels
  apps.ngrok.enable = true; # ngrok tunnel tool

  # AI
  apps.ollama.enable = true; # Local LLM runner (Apple Silicon GPU)

  # ============================================
  # SYSTEM SERVICES (handled separately)
  # ============================================
  # - Tailscale: modules/core/networking on NixOS, darwin/core/networking on Darwin
  darwin.core.networking.tailscale.enable = true;

  # Auto-cleanup Downloads folder (files older than 30 days)
  core.downloads-cleanup.enable = true;

  # ============================================
  # APPS THAT DON'T WORK ON DARWIN (NixOS-only)
  # ============================================
  # - apps.i3, apps.bumblebee-status, apps.dunst, redshift (X11)

  # User configuration (already set in system module, but can be overridden here)
  # users.users.${username} = {
  #   name = username;
  #   home = "/Users/${username}";
  #   shell = pkgs.fish;
  # };
}
