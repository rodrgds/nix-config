# Shared 9Router combo catalog.
#
# Single source of truth for the public combo names served by the 9Router
# gateway on the VPS. Consumed by:
#   - modules/apps/opencode -> opencode provider model list
#   - modules/apps/pi       -> Pi custom models provider
#
# Combos are created and routed in the 9Router dashboard. The rebuild wizard
# refreshes `9router/combos.json` from the proxy's /v1/models endpoint (combos
# only) before every rebuild, so models.json picks up new combos automatically.
# The snapshot stays committed, which keeps pure rebuilds and `nix flake check`
# working without network access; edit it manually only to pin entries.
{
  inherit (builtins.fromJSON (builtins.readFile ./9router/combos.json)) models;
}
