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
- Hyprland/Wayland desktop with Quickshell and gaming tools
- VPS stack with reverse proxy, Podman services, and Tailscale

### Hosts

| Host | Platform | Notes |
| --- | --- | --- |
| `rgo-desktop` | NixOS | Main desktop, Hyprland, Quickshell, gaming |
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

- Hyprland, Quickshell, Hyprlock, Hypridle, Dunst; dormant i3/Polybar modules remain available
- Steam, CS2, Prism Launcher, Lunar Client, Wine, Winetricks, MangoHud, GameMode
- OBS, Darktable, GIMP, NormCap, and Charm Freeze
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

### Application and website hosting

User-facing application delivery is grouped under `modules/hosting/`, separate from reusable service/runtime declarations. `modules/hosting/sites/` owns static/source-built sites, while `modules/hosting/deployments/default.nix` owns the authenticated webhook receiver, repository allow-listing, systemd deploy units, health checks, and old-image pruning. Runtime/container modules remain under `modules/services/`.

OpenPost, Montra, and Unprompted publish verified GHCR images before calling their signed VPS hooks. Personal Website deploys verified source revisions. `edu.rgo.pt` is hosted by the Git-integrated Cloudflare Pages project in `rodrgds/edu`; do not add it back to VPS Caddy or the deployment webhook. Montra and Unprompted share rootful Podman authentication through `packages_ghcr_token`, a read-only package PAT rendered by `sops-nix`. When changing a VPS-hosted repository, image name, unit name, domain, health endpoint, or build directory, update both the project workflow/`AGENTS.md` and the matching Nix hosting module. Do not add parallel ad-hoc deploy scripts on the server. After rebuilding `rgo-vps`, verify `webhook-deploy.service`, the relevant deployment hook, its application units, and the public health URL.

## Platform Differences

| Area | `rgo-desktop` | `rgo-laptop` |
| --- | --- | --- |
| Window manager | Hyprland | Aerospace |
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

The desktop login defaults to the UWSM-managed Hyprland session. The old i3,
Polybar, and Redshift modules remain in the repository but are disabled on this
host, so they no longer add an X11 desktop session or background services.

#### Hyprland migration notes

- The familiar Super-based workspace, focus, move, fullscreen, launcher, screenshot,
  and application bindings are mirrored in Hyprland.
- `Super+G` creates a tabbed Hyprland group, `Super+E` toggles the split, and
  `Super+H`/`Super+V` choose the next split direction.
- Quickshell renders a 28 px bar on each connected monitor. It keeps workspaces on
  the left and CPU, RAM, disk, audio, controls, tray, clock, and power on the right.
- Choose `Hyprland (UWSM-managed)` at login. UWSM owns the systemd session,
  imports the Wayland environment, starts graphical user services, and tears them
  down cleanly; the plain Hyprland entry starts the compositor directly.
- CS2 launches directly through SDL3's native Wayland backend at 1280x960.
  Gamescope is intentionally not used because its Wayland Vulkan backend aborts
  on this NVIDIA setup.
- VRR, tearing, and direct scanout are intentionally off for the first baseline.
  Measure the stable configuration before enabling those experimental paths.
- Grim/Slurp handle Hyprland screenshots, and OBS screen capture uses the
  Hyprland desktop portal.

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
Its production EnvironmentFile is rendered by `sops-nix` from the dedicated `unprompted_*`
entries in `secrets/vps-secrets.yaml`; do not create or edit a plaintext copy on the VPS. Private
Montra and Unprompted images use the shared `packages_ghcr_token` secret, which needs only
`read:packages`. Unprompted webhook requests use a separate `unprompted_deploy_webhook_secret`, so
other deployment senders cannot sign an Unprompted release.

The host configuration pins one verified Unprompted revision and all four image digests for an empty
local image-store bootstrap. Rebuilding `rgo-vps` pulls those exact digests only when a local image is
missing, verifies their common OCI revision label, tags the complete set locally, runs migrations, and
starts API/worker before web. A reboot with an intact local image set never follows a mutable registry
tag.

Later pushes to Unprompted build and scan each image by digest in CI. After all four scans pass, CI
creates the `sha-<commit>` registry tags and sends the same four approved digests through the signed
deployment hook. The VPS pulls by digest, resolves the verified local migration tag to its image ID,
runs it with registry pulls disabled while the old application keeps serving, then restarts and
health-checks the new containers. Production never checks
out or builds Unprompted source. `PRODUCTION_DEPLOY_ENABLED=true` enables these verified automatic
rollouts; set it to `false` only when deployments need to be paused.

The signed JSON deployment payload must include integer `issued_at` (Unix epoch) and a unique,
safe `delivery_id` in addition to the repository, exact revision, and all four digests. The receiver
checks the HMAC over the exact raw body before parsing it, accepts payloads no more than five minutes
old or 60 seconds in the future, and atomically records delivery IDs under `/var/lib/unprompted` before
launching a deployment. A failed or ambiguous delivery is retried only by a new CI run attempt with a
new ID and timestamp. Transient deployment logs stay in the systemd journal; the webhook returns only
the exact `DEPLOY_OK` success line expected by CI.

Unprompted bootstrap/tagging, boot migration, deployment migration and promotion/restart/rollback,
and global image cleanup serialize on `/run/podman-maintenance.lock`. The deployment transient unit
owns the lock while its migration child runs, avoiding a nested lock. Rollback requires a complete
four-image previous release, restores and verifies the exact recorded image IDs (including the
migration image), verifies running API/worker/web image IDs, and requires internal and public health
before reporting success. Automated cleanup prunes dangling images and build cache only; tagged active
release images are retained even when no persistent container references them.

#### Montra production images

Montra publishes only runtime surfaces affected by each commit. Every matrix job records the scanned
manifest digest for its `api`, `web`, `embedding`, `detector`, or `postgres` image. The final job sends
a signed payload containing the exact commit, timestamp, unique run-attempt delivery ID, and a nonempty
component-to-digest map. The receiver rejects unknown fields/components, malformed digests, stale or
future timestamps, repository mismatches, and replayed delivery IDs before launching a transient deploy
unit. Unlisted components remain untouched, so a path-filtered release does not require unrelated
images to carry the new commit label.

The VPS pulls listed candidates by digest, verifies each OCI revision label against the requested
commit, records complete local rollback image IDs, then promotes only those local `latest` tags. Montra
containers use `--pull=never`; after each selected restart the deploy verifies the running container
image ID. API promotion includes both workers and pre-restart migration/configuration. Model-service
promotion requires its model-loading readiness endpoint, and the final gate covers every internal
service plus the public site. On failure, selected tags and services are restored and rechecked; database
migrations are forward-only and are not reversed.

The host pins one independently verified bootstrap digest and revision per Montra image for recovery
when a local tag is absent. It does not force all current images to one revision because path-filtered
releases intentionally leave unchanged surfaces on their last verified revisions. Deployments and
catalog mutations serialize on `/run/montra-catalog-maintenance.lock`, followed by the global Podman
maintenance lock. Production admin jobs acquire the shared lock before claiming work. Run manual
catalog operations through `montra-catalog-maintenance <command> [args...]` so deploys cannot restart
workers during a mutation.

Production appearance processing rewrites only URLs under the configured
`VISUAL_APPEARANCE_PUBLIC_IMAGE_BASE_URL` prefix to the matching
`VISUAL_APPEARANCE_INTERNAL_IMAGE_BASE_URL` prefix before the embedding service fetches them. The
deployed mapping is `http://127.0.0.1:9000/fashion-radar` to `https://media.montra.style`. The service
allowlists that exact HTTPS origin; unrelated retailer URLs keep the normal public-host validation and
fallback behavior.

## Operations

### Rebuilds

```bash
# Desktop
rebuild --desktop

# Laptop
rebuild --laptop

# VPS (deploy-rs; builds locally on desktop or remotely from laptop)
rebuild --vps

# Direct fallback commands
nh os switch ~/.config/home -H rgo-desktop
nh darwin switch ~/.config/home -H rgo-laptop
nix flake check ~/.config/home --no-build --all-systems --impure
# From rgo-desktop: build locally, then copy and activate on the VPS
nix run ~/.config/home#deploy-rs -- --skip-checks ~/.config/home#rgo-vps -- --impure
# From rgo-laptop: build on the x86_64-linux VPS
nix run ~/.config/home#deploy-rs -- --skip-checks --remote-build ~/.config/home#rgo-vps -- --impure
sudo nixos-rebuild switch --flake "$HOME/.config/home#rgo-desktop"
darwin-rebuild switch --flake "$HOME/.config/home#rgo-laptop"
```

### Rebuild TUI

`rebuild` is not just a shell alias for `nixos-rebuild` or `darwin-rebuild`.

Run plain `rebuild` to open the TUI. `rebuild --desktop`, `rebuild --laptop`,
and `rebuild --vps` bypass it and immediately start the corresponding rebuild.
The VPS path retains the deploy-rs build-host selection and magic rollback flow.
Local rebuilds show activation logs, including long-running Homebrew work on macOS.
`rebuild --help` lists every configured direct target. The canonical target
metadata—CLI flag, flake attribute, platform kind, allowed source hosts, and
remote-build policy—lives together in `tools/rebuild-wizard/config.ts`.

It runs the Bun-based rebuild wizard in `tools/rebuild-wizard/rebuild.ts` and is wired by the `scripts` module. In practice it can:

- select the rebuild target
- optionally update selected flake inputs
- show git status and diff before rebuilding
- run `statix` and `nixfmt`
- deploy `rgo-vps` with target-side builds and deploy-rs magic rollback
- run the correct local `nh` command for the desktop or laptop

The VPS deploy profile connects to `rgo@rgo-vps`, activates the root NixOS system through
passwordless sudo, and keeps deploy-rs automatic and magic rollback enabled. The wizard builds the
VPS closure locally on the x86_64-linux desktop, but automatically selects a target-side build from
the Apple Silicon laptop. It evaluates all flake and deploy checks first, then skips deploy-rs's
duplicate local build checks.

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
