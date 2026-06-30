# NixOS and macOS Config

![Screenshot](screenshot.png)

Personal flake-based config for:

- `rgo-desktop` on NixOS (`x86_64-linux`)
- `rgo-laptop` on macOS (`aarch64-darwin`)
- `rgo-vps` on NixOS

It uses shared modules, Home Manager, `nh`, `sops-nix`, and a Bun-based rebuild TUI.

## Overview

### Highlights

- One repo for desktop, laptop, and VPS
- Shared modules with platform-specific gating where needed
- Home Manager integrated into both NixOS and nix-darwin
- Homebrew integration on macOS
- `sops-nix` for both personal and server secrets
- TUI rebuild flow with target selection, diff view, formatting, and optional flake input updates
- Development setup for web, mobile, systems, and AI tooling
- Linux desktop stack with i3 and gaming tools
- VPS stack with reverse proxy, Podman services, and Tailscale

### Hosts

| Host | Platform | Notes |
| --- | --- | --- |
| `rgo-desktop` | NixOS | Main desktop, i3, gaming, Linux-only apps |
| `rgo-laptop` | macOS | nix-darwin, Aerospace, Homebrew integration |
| `rgo-vps` | NixOS | Remote services and containers |

### Layout

```text
.
├── flake.nix
├── hosts/
├── modules/
├── packages/
├── secrets/
└── tools/
```

## What’s In Here

### Shared base

- Ghostty
- Bash, Git, GitHub CLI, SSH
- Neovim and Zed
- Node.js, Bun, Python, Go, Graphviz, Doxygen
- VS Code, Android Studio, Android SDK, DBeaver
- Obsidian, MPV, qBittorrent
- Codex, Claude, Antigravity CLI, Opencode, and Pi

### NixOS desktop

- i3, bumblebee-status, dunst, redshift
- Steam, CS2, Prism Launcher, Lunar Client, Wine, Winetricks, MangoHud, GameMode
- OBS, Darktable, GIMP, DaVinci Resolve, Flameshot, NormCap, Charm Freeze
- Solaar, Synology Drive, ngrok, Vicinae, Grayjay, Rescrobbled

### macOS laptop

- Aerospace and JankyBorders
- Homebrew-managed GUI apps where needed
- Edge, Ghostty, Telegram, TeamSpeak, Beeper, Surfshark
- UTM/QEMU, CLion, Affinity, Cap, Stremio
- Syncthing, Tailscale, ngrok, Ollama

### VPS

Current enabled services include:

- Caddy
- AdGuard Home
- Vaultwarden
- Umami
- TeamSpeak
- Directus
- TRNDb
- n8n
- Shlink
- OpenPost
- Podman-based service infrastructure

Some heavier or experimental services remain disabled until needed.

## Platform Differences

| Area | `rgo-desktop` | `rgo-laptop` |
| --- | --- | --- |
| Window manager | i3 | Aerospace |
| Service manager | systemd | launchd |
| Package source | nixpkgs | nixpkgs + Homebrew |
| Flatpak | yes | no |
| Ollama | currently off | Homebrew install |
| Gaming stack | yes | no |

Notes:

- Linux-only modules still exist in the shared tree, so option gating matters
- Flatpak is Linux-only in this repo
- `apps.ollama` on macOS currently installs via Homebrew, not `pkgs.ollama`

## Secrets

This repo uses `sops-nix`, but not the same way on every host.

- `rgo-desktop` and `rgo-laptop` use the Home Manager `sops` module for personal secrets
- `rgo-vps` uses the system `sops` module for service secrets
- the current personal age key path is `~/.config/sops/age/keys.txt`
- the VPS system key path is `/root/.config/sops/age/keys.txt`

Important Darwin detail:

- on macOS, this repo currently uses Home Manager `sops.secrets.<name>.path`
- do not assume `sops.templates` or `config.sops.placeholder.*` are available on Darwin in this setup

### Personal machine secrets

Expected key path:

```bash
~/.config/sops/age/keys.txt
```

If you already have the key, copy it there before rebuilding.

If you need a new one:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
grep "public key" ~/.config/sops/age/keys.txt
```

Then update `secrets/.sops.yaml`, re-encrypt `secrets/secrets.yaml`, and commit the changes.

## Installation

### macOS

#### Prerequisites

```bash
xcode-select --install
```

Install Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install Nix:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

Enable flakes:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Clone:

```bash
git clone https://github.com/yourusername/nix-config.git ~/.config/home
cd ~/.config/home
```

First switch:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:lnl7/nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#rgo-laptop'
```

Open these apps once after install so macOS permission prompts appear:

- Aerospace
- Karabiner
- Raycast
- Syncthing
- JankyBorders

If something looks broken, check `System Settings -> Privacy & Security`.

### NixOS desktop

First install:

```bash
cd ~/.config/home
sudo nixos-install --flake '.#rgo-desktop'
```

Fallback direct rebuild:

```bash
sudo nixos-rebuild switch --flake "$HOME/.config/home#rgo-desktop"
```

### VPS

First install:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake '.#rgo-vps' \
  --target-host root@<server-ip> \
  --build-on local \
  --no-substitute-on-destination
```

Then:

1. Generate an age key on the VPS at `~/.config/sops/age/keys.txt`
2. Add the VPS public key to `secrets/.sops.yaml`
3. Re-encrypt `secrets/secrets.yaml` and `secrets/vps-secrets.yaml`
4. Copy the key to `/root/.config/sops/age/keys.txt`
5. Run `rebuild` and choose the VPS target in the TUI

#### Unprompted production env

`rgo-vps` defines `unprompted.to`, `www.unprompted.to`, and `api.unprompted.to` through Caddy.
Before starting the app, create the production EnvironmentFile on the VPS:

```bash
sudo install -d -m 0750 /var/lib/unprompted
sudo cp /etc/unprompted/production.env.example /var/lib/unprompted/production.env
sudo $EDITOR /var/lib/unprompted/production.env
sudo systemctl restart podman-unprompted-postgres unprompted-build unprompted-api unprompted-worker unprompted-web
```

Point DNS for `unprompted.to`, `www.unprompted.to`, and `api.unprompted.to` at the VPS. The
systemd units are guarded with `ConditionPathExists`, so the NixOS switch succeeds before the real
env file exists, but the app services intentionally stay inactive until it is present.
The build unit clones `https://github.com/rodrgds/unprompted` by default, so publish that repo or
override `vps.unprompted.repository` before starting `unprompted-build`.

## Operations

### Rebuilds

```bash
# Desktop
rebuild

# Laptop
rebuild --laptop

# Direct fallback commands
nh os switch ~/.config/home -H rgo-desktop
nh darwin switch ~/.config/home -H rgo-laptop
sudo nixos-rebuild switch --flake "$HOME/.config/home#rgo-desktop"
darwin-rebuild switch --flake "$HOME/.config/home#rgo-laptop"
```

### Rebuild TUI

`rebuild` is not just a shell alias for `nixos-rebuild` or `darwin-rebuild`.

It runs the Bun-based rebuild wizard in `tools/rebuild-wizard/rebuild.ts` and is wired by the `scripts` module. In practice it can:

- select the rebuild target
- optionally update selected flake inputs
- show git status and diff before rebuilding
- run `statix` and `nixfmt`
- run the correct rebuild command for the chosen target

### Secrets management

```bash
# Edit personal secrets
sops secrets/secrets.yaml

# Edit VPS secrets
sops secrets/vps-secrets.yaml

# Update keys after adding a machine
sops updatekeys secrets/secrets.yaml
sops updatekeys secrets/vps-secrets.yaml
```

### Maintenance

```bash
# Update flake inputs
nix flake update

# Run checks
nix flake check

# Cleanup with nh
nh clean all -k 3

# Traditional garbage collection
nix-collect-garbage -d
```

<details>
<summary><strong>Extra Maintenance Commands</strong></summary>

### Nix store cleanup

If `/nix/store` grows too much:

```bash
# Delete old Home Manager generations
home-manager expire-generations "-7 days"

# Delete old system generations
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

# Clean auto GC roots from direnv/develop shells
sudo rm -rf /nix/var/nix/gcroots/auto/*

# Remove stale result symlinks
find ~ -maxdepth 4 -name "result" -type l -mtime +7 -delete 2>/dev/null

# Full GC + optimise
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

`angrr` is enabled to help remove stale GC roots automatically.

### Nix tools

Bundled in `apps.nix-tools`:

- `nh` for rebuilds and cleanup
- `comma` for ad-hoc package execution
- `nix-index` for file lookup
- `angrr` for GC root cleanup
- `nurl` for fetcher expressions
- `nix-init` for package scaffolding
- `statix` for linting
- `nil` for the language server
- `nixfmt` for formatting
- `home-manager` CLI

```bash
# Run a package without installing it
, cowsay "hello"

# Find which package owns a file
nix-locate 'bin/hello'

# Generate a fetcher expression from a URL
nurl https://github.com/nix-community/patsh v0.2.0

# Scaffold a package
nix-init

# Lint Nix files
statix check .
statix fix .
```

</details>

<details>
<summary><strong>VPS Migration</strong></summary>

Typical flow for a replacement VPS:

1. deploy the new host with `nixos-anywhere`
2. add its age key to `secrets/.sops.yaml`
3. re-encrypt secrets
4. copy service data from `/var/lib/<service>/`
5. fix ownership
6. rebuild and verify services

Useful commands:

```bash
# Stop services on the new VPS before copying data
ssh rgo@<new-server-ip> "sudo systemctl stop podman-n8n podman-vaultwarden podman-umami podman-shlink podman-directus podman-teamspeak podman-ghost podman-postiz podman-unieasy 2>/dev/null; echo Services stopped"

# Copy service data from the old VPS
sudo rsync -avz --delete --rsync-path="sudo rsync" /var/lib/<service>/ rgo@<new-server-ip>:/var/lib/<service>/

# Fix common permissions on the new VPS
ssh rgo@<new-server-ip> "
sudo chown -R root:root /var/lib/vaultwarden /var/lib/shlink /var/lib/caddy 2>/dev/null
sudo chown -R 999:999 /var/lib/n8n/postgres 2>/dev/null
sudo chown -R 70:70 /var/lib/umami/postgres 2>/dev/null
sudo chown -R 1000:1000 /var/lib/directus /var/lib/n8n/data 2>/dev/null
sudo chown -R 9987:9987 /var/lib/teamspeak 2>/dev/null
sudo chown -R root:root /var/lib/tailscale 2>/dev/null
echo 'Permissions fixed'
"

# Restart common services
ssh rgo@<new-server-ip> "sudo systemctl restart podman-vaultwarden podman-n8n podman-umami podman-shlink podman-directus podman-teamspeak 2>/dev/null; echo Services restarted"

# Verify
ssh rgo@<new-server-ip> "sudo systemctl list-units --state=failed --no-pager | grep podman; df -h"
```

Copy data from `/var/lib/<service>/`, not `/var/lib/containers/`.

</details>

## Troubleshooting

### macOS: `homebrew` option does not exist

You are probably trying to build the macOS host on NixOS or vice versa. Use the correct host:

- `rgo-laptop` for macOS
- `rgo-desktop` for NixOS

### SOPS: failed to decrypt

- verify `~/.config/sops/age/keys.txt` exists
- verify the public key in `secrets/.sops.yaml` matches your private key
- ensure permissions are correct:

```bash
chmod 600 ~/.config/sops/age/keys.txt
```

### macOS: `_nixbld1 does not exist` after macOS update

See `NixOS/nix#10892`.

### First build takes a long time

Normal. The first build downloads and builds a lot more than later rebuilds.

## Why This Repo Might Be Useful

If you are deciding whether to borrow from this config, the main selling points are:

- mixed NixOS + macOS management in one repo
- a relatively large app/tool catalog already split by platform
- practical secrets handling for both personal machines and a VPS
- a real rebuild workflow instead of only raw `switch` commands
- examples of handling Linux-only modules in a shared tree without duplicating the whole config

## Customizing

If you fork this repo, change at minimum:

1. `username` in `flake.nix`
2. keys in `secrets/.sops.yaml`
3. values in `secrets/secrets.yaml`
4. host-specific settings under `hosts/`

## TODO

- [ ] Use `bun2nix` for managing Bun packages in Nix
- [ ] Consider `flake-parts` if flake outputs grow a lot more
