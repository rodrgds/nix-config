# NixOS and macOS Config

![Screenshot](screenshot.png)

Personal flake-based config for:

- `rgo-desktop` on NixOS (`x86_64-linux`)
- `rgo-laptop` on macOS (`aarch64-darwin`)
- `rgo-vps` on NixOS

It uses shared modules, Home Manager, `nh`, and `sops-nix`.

## Layout

```text
.
├── flake.nix
├── hosts/
├── modules/
├── packages/
├── secrets/
└── tools/
```

## Hosts

| Host | Platform | Notes |
| --- | --- | --- |
| `rgo-desktop` | NixOS | Main desktop, i3, gaming, Linux-only apps |
| `rgo-laptop` | macOS | nix-darwin, Aerospace, Homebrew integration |
| `rgo-vps` | NixOS | Remote services and containers |

## Secrets

This repo uses `sops-nix`, but not the same way on every host.

- `rgo-desktop` and `rgo-laptop` use the Home Manager `sops` module for personal secrets
- `rgo-vps` uses the system `sops` module for service secrets
- the age key path currently used by personal machines is `~/.config/sops/age/keys.txt`
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

## macOS Setup

### 1. Prerequisites

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

### 2. Clone

```bash
git clone https://github.com/yourusername/nix-config.git ~/.config/home
cd ~/.config/home
```

### 3. First Darwin switch

```bash
nix --extra-experimental-features 'nix-command flakes' run github:lnl7/nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#rgo-laptop'
```

### 4. Normal rebuilds

Preferred:

```bash
rebuild --laptop
```

Fallback:

```bash
nh darwin switch ~/.config/home -H rgo-laptop
```

Or:

```bash
darwin-rebuild switch --flake "$HOME/.config/home#rgo-laptop"
```

### 5. Open macOS apps once

Some apps need manual permission approval after install:

- Aerospace
- Karabiner
- Raycast
- Syncthing
- JankyBorders

Check `System Settings -> Privacy & Security` if something looks broken.

## NixOS Setup

Clone the repo and switch:

```bash
cd ~/.config/home
sudo nixos-install --flake '.#rgo-desktop'
```

Later rebuilds:

```bash
rebuild
```

Fallback:

```bash
nh os switch ~/.config/home -H rgo-desktop
```

Or:

```bash
sudo nixos-rebuild switch --flake "$HOME/.config/home#rgo-desktop"
```

## VPS Setup

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

## Commands

```bash
# Desktop
rebuild

# Laptop
rebuild --laptop

# Update flake inputs
nix flake update

# Check flake
nix flake check

# Cleanup
nh clean all -k 3
```

### Rebuild script

`rebuild` is not just a shell alias for `nixos-rebuild` or `darwin-rebuild`.

It runs the Bun-based rebuild wizard in `tools/rebuild-wizard/rebuild.ts` and is wired by the `scripts` module. In practice it can:

- select the rebuild target
- optionally update selected flake inputs
- show git status and diff before rebuilding
- run `statix` and `nixfmt`
- run the correct rebuild command for the chosen target

## Notes

- macOS uses `nixpkgs-darwin` plus Homebrew integration
- Linux-only modules still exist in the shared tree, so platform gating matters
- `apps.ollama` on macOS currently installs via Homebrew, not `pkgs.ollama`
- Flatpak is Linux-only in this repo

## Customizing

If you fork this repo, change at minimum:

1. `username` in `flake.nix`
2. keys in `secrets/.sops.yaml`
3. values in `secrets/secrets.yaml`
4. host-specific settings under `hosts/`
