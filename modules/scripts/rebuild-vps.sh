#!/usr/bin/env bash
set -e

# Get VPS IP from sops secrets using nix run
IP=$(nix run nixpkgs#sops -- --decrypt --extract '["rgo_vps_ip"]' "$HOME/.config/home/secrets/secrets.yaml" | tr -d '\n\r')

echo "🚀 Deploying to rgo-vps at ${IP}..."

# Build and deploy remotely (avoids unsigned store path issues)
nixos-rebuild switch \
  --flake "$HOME/.config/home#rgo-vps" \
  --target-host "rgo@${IP}" \
  --build-host "rgo@${IP}" \
  --sudo

echo "✅ Deployment complete!"
