---
name: nix-config-vps-migration
description: "Move service data to a replacement rgo-vps: deploy, add age key, copy data, fix ownership, rebuild, verify."
disable-model-invocation: true
---

# Migrating to a replacement VPS

1. Deploy the new host with `nixos-anywhere`.
2. Add its age key to `secrets/.sops.yaml`.
3. Re-encrypt with `sops updatekeys secrets/vps-secrets.yaml`.
4. Copy service data from `/var/lib/<service>/`, not `/var/lib/containers/`.
5. Fix ownership.
6. Rebuild and verify services.

## Stop services on the new VPS before copying

```bash
ssh rgo@<new-server-ip> "sudo systemctl stop podman-n8n podman-vaultwarden podman-umami podman-shlink podman-directus podman-teamspeak podman-ghost podman-postiz podman-unieasy 2>/dev/null; echo Services stopped"
```

## Copy service data from the old VPS

```bash
sudo rsync -avz --delete --rsync-path="sudo rsync" \
  /var/lib/<service>/ rgo@<new-server-ip>:/var/lib/<service>/
```

## Fix permissions on the new VPS

```bash
ssh rgo@<new-server-ip> "
sudo chown -R root:root /var/lib/vaultwarden /var/lib/shlink /var/lib/caddy 2>/dev/null
sudo chown -R 999:999 /var/lib/n8n/postgres 2>/dev/null
sudo chown -R 70:70 /var/lib/umami/postgres 2>/dev/null
sudo chown -R 1000:1000 /var/lib/directus /var/lib/n8n/data 2>/dev/null
sudo chown -R 9987:9987 /var/lib/teamspeak 2>/dev/null
sudo chown -R root:root /var/lib/tailscale 2>/dev/null
echo 'Permissions fixed'
"
```

## Restart and verify

```bash
ssh rgo@<new-server-ip> "sudo systemctl restart podman-vaultwarden podman-n8n podman-umami podman-shlink podman-directus podman-teamspeak 2>/dev/null; echo Services restarted"
ssh rgo@<new-server-ip> "sudo systemctl list-units --state=failed --no-pager | grep podman; df -h"
```

Done when the last command reports no failed podman units and disk has free space.
