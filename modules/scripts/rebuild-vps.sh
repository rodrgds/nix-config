#!/usr/bin/env bash
set -e

echo "🚀 Deploying to rgo-vps via Tailscale..."

# Build and deploy remotely using Tailscale MagicDNS name
nixos-rebuild switch \
  --flake "$HOME/.config/home#rgo-vps" \
  --target-host "rgo@rgo-vps" \
  --build-host "rgo@rgo-vps" \
  --sudo \
  --ask-sudo-password

echo "✅ Deployment complete!"
