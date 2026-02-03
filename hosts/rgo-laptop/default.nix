# MacBook Pro M4 (aarch64-darwin) configuration - rgo-laptop
{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./homebrew.nix # Host-specific Homebrew additions (optional)
    ./system.nix
  ];

  # Enable Darwin core modules
  darwin.core.system.enable = true;
  darwin.core.networking.enable = true;
  darwin.core.fonts.enable = true;
  darwin.core.homebrew.enable = true;
  darwin.core.karabiner.enable = true;

  # Enable scripts (rebuild command and aliases)
  scripts.enable = true;

  # Enable secrets management
  secrets.enable = true;

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
  apps.fish.enable = true; # Gruvbox plugin, fzf, macOS Homebrew PATH setup
  apps.git.enable = true; # Git config, osxkeychain credential helper
  apps.neovim.enable = true; # Neovim with EDITOR env var
  apps.starship.enable = true; # Starship prompt with Fish integration

  # Development
  apps.nodejs.enable = true; # Node.js with npm config
  apps.bun.enable = true; # Bun JavaScript runtime
  apps.python.enable = true; # Python with pip config
  apps.vscode.enable = true; # VSCode: (unfree, available in nixpkgs)
  apps.opencode.enable = true; # CLI tool with gruvbox theme
  apps.dbeaver.enable = true; # DBeaver database tool (available in nixpkgs)

  # Communication
  apps.telegram.enable = true; # Telegram Desktop (available in nixpkgs)
  # apps.teamspeak.enable = true; # TeamSpeak - NixOS only (not in Homebrew)
  apps.beeper.enable = true; # Beeper messaging

  # Productivity
  apps.obsidian.enable = true; # Obsidian (unfree, available in nixpkgs)
  apps.raycast.enable = true; # Launcher (Homebrew on Darwin)
  apps.flameshot.enable = true; # Screenshots (Homebrew on Darwin)

  # Media
  apps.mpv.enable = true; # MPV with custom Lua script for camera toggle
  apps.stremio.enable = true; # Stremio (nixpkgs on Linux, Homebrew on Darwin)

  # System
  apps.syncthing.enable = true; # File sync (systemd on NixOS, Homebrew on Darwin)

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
