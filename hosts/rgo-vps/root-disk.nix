# Shared root-disk identity for rgo-vps.
#
# Single source of truth for the root filesystem UUID. Consumed by:
#   - disko.nix    - pins the UUID at install time so a disaster-recovery
#                    reinstall reproduces it
#   - default.nix  - mounts "/" by this UUID (not the GPT partlabel) so the
#                    host survives GPT partition-name loss
{
  uuid = "3aabb224-f4e6-467e-af6b-00cdd6d41936";
}
