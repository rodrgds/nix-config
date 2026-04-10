#!/usr/bin/env bash
set -e

echo "🚀 Deploying to rgo-vps via Tailscale..."

# Build locally, deploy to VPS.
# This avoids OOM failures on small VPS instances when heavy packages compile.
nixos-rebuild switch \
  --flake "$HOME/.config/home#rgo-vps" \
  --target-host "rgo@rgo-vps" \
  --build-host "rgo@rgo-vps" \
  --sudo \
  --ask-sudo-password

echo "✅ Deployment complete!"
