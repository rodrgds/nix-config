# NixOS Configuration

![Screenshot](screenshot.png)

This is my personal NixOS configuration using flakes and home-manager.

## Features

- **Flakes** - Modern NixOS configuration with flake support
- **Home Manager** - User environment managed as part of the system
- **Modular Structure** - Clean separation with 4 root folders:
  - `hosts/` - Host-specific configurations
  - `modules/` - All system and app modules
  - `packages/` - Custom packages and overlays
  - `secrets/` - Encrypted secrets with sops-nix
- **i3 Window Manager** - Tiling window manager with custom keybindings
- **Gruvbox Theme** - Consistent theming across terminal, apps, and desktop
- **Gaming Setup** - Steam, CS2, and various gaming tools configured
- **Development Environment** - Full setup for web, mobile, and systems development

## Important: Customization Required

If you fork this config, you'll need to change:

- **Username** in `flake.nix` (currently "rgo")
- **System settings** in `hosts/rgopc/` for your hardware
- **Secrets** in `secrets/secrets.yaml` (see [sops-nix](https://github.com/Mic92/sops-nix))
- **Personal preferences** in various modules

My suggestion is to take the bits you like and adapt them to your own setup.

## Quick Start

### Existing NixOS Installation

1. Clone this repo:
   ```bash
   git clone https://github.com/yourusername/nix-config.git ~/.config/home
   cd ~/.config/home
   ```

2. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#rgopc --impure
   ```

### New Installation

1. Install NixOS from ISO
2. Generate hardware config:
   ```bash
   nixos-generate-config --root /mnt
   ```
3. Copy `hardware-configuration.nix` to `hosts/rgopc/`
4. Install:
   ```bash
   nixos-install --flake .#rgopc
   ```

## Structure

```
.
├── flake.nix              # Main flake configuration
├── hosts/
│   └── rgopc/            # Host-specific config
│       ├── default.nix
│       ├── hardware.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── constants.nix     # Shared constants (fonts, colors)
│   ├── apps/             # Application modules (50+)
│   ├── core/             # System core modules
│   └── scripts/          # Custom scripts with auto-aliases
├── packages/             # Custom packages
│   ├── fonts/
│   └── davinci-resolve/
└── secrets/              # Encrypted secrets
    ├── secrets.yaml
    └── .sops.yaml
```

## Useful Aliases

- `rebuild` - Rebuild the system
- `edit-secrets` - Edit encrypted secrets
- `decrypt-secrets` - Decrypt secrets to stdout
- `decrypt-to-file` - Decrypt secrets to a temporary file for editing
- `encrypt-secrets` - Encrypt secrets from file (auto-deletes decrypted file)
- `copy` - Copy to clipboard (xclip)
- `v` - Open nvim
- `glog` - Pretty git log

## TODO

- [ ] Add more documentation for individual modules
- [ ] Consider migration to flake-parts
- [ ] Add more automated tests

## Credits

Inspired by various NixOS configurations in the community.
