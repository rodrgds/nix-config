---
name: nix-config-hosting
description: "Delivery model for user-facing apps on rgo-vps: sites vs deployments vs runtime modules, which apps deploy how, and post-rebuild verification."
disable-model-invocation: true
---

# Hosting sites and deployments on rgo-vps

User-facing delivery splits into two concerns, separate from reusable runtime declarations:

- `modules/hosting/sites/` - static or source-built sites.
- `modules/hosting/deployments/` - the signed webhook receiver, repository allow-listing, systemd deploy units, health checks, image pruning.
- `modules/services/` - reusable runtime/container declarations.

## Delivery model

- OpenPost, Montra, and Unprompted publish verified GHCR images, then call their signed VPS hooks.
- Personal Website deploys verified source revisions.
- Montra and Unprompted share rootful Podman auth through the read-only `packages_ghcr_token` PAT rendered by `sops-nix`.
- `edu.rgo.pt` lives on Cloudflare Pages (`rodrgds/edu`), not on the VPS - leave it there.

The signed rollout contract for Unprompted and Montra lives in the `nix-config-signed-deploys` skill.

## Verify after a VPS rebuild

Confirm `webhook-deploy.service`, the relevant deployment hook, its application units, and the public health URL all come up healthy.
