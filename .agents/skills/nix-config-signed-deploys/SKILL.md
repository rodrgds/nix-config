---
name: nix-config-signed-deploys
description: "Verified rollout contract for Unprompted and Montra on rgo-vps: signed payload, digest verification, and maintenance locks."
disable-model-invocation: true
---

# Verified signed deploys (Unprompted + Montra)

CI builds and scans the images; the VPS only pulls them by digest.

## Signed payload

Every webhook request is HMAC-checked over the exact raw body before parsing. The payload carries:

- `issued_at` - integer Unix epoch.
- `delivery_id` - unique per run-attempt.
- repository, exact revision, image digests.

The receiver accepts payloads no more than five minutes old or 60 seconds in the future and records delivery IDs atomically before deploying. A failed or ambiguous delivery is retried only by a new CI attempt with a new ID and timestamp. Deploy logs stay in the systemd journal; the webhook returns only the `DEPLOY_OK` line CI expects.

## Unprompted

- Four images (api, worker, web, migrate) pin one verified revision and four digests for empty-store bootstrap; an intact local set means a reboot uses the pinned digests and pulls nothing.
- Rollout pulls by digest, verifies the OCI revision label, migrates with registry pulls disabled while the old app serves, then restarts and health-checks.
- `PRODUCTION_DEPLOY_ENABLED=true` enables automatic rollouts; set `false` to pause.
- Rollback needs a complete four-image previous release, restores exact image IDs, and requires internal + public health before success.

## Montra

- Publishes only the surfaces a commit touches; the payload carries a nonempty component-to-digest map (`api`, `web`, `embedding`, `detector`, `postgres`). Unlisted components stay untouched.
- Promotes only local `latest` tags; containers use `--pull=never`; model-service promotion requires its model-loading readiness endpoint.
- Database migrations are forward-only.

## Locks

- Montra deployments and catalog mutations serialize on `/run/montra-catalog-maintenance.lock`, then the global `/run/podman-maintenance.lock`.
- Run manual catalog work through `montra-catalog-maintenance <command> [args...]` so deploys and mutations serialize.
