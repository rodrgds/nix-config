import { join } from "./fs";
import type { Target } from "./types";

export const HOST_ALIASES: Record<string, string> = {
  rgopc: "rgo-desktop",
};

export const TARGETS: Target[] = [
  {
    name: "rgo-laptop",
    flakeAttr: "rgo-laptop",
    kind: "darwin",
    description: "Local nix-darwin rebuild",
    allowedFrom: ["rgo-laptop"],
  },
  {
    name: "rgo-desktop",
    flakeAttr: "rgo-desktop",
    kind: "nixos",
    description: "Local NixOS rebuild",
    allowedFrom: ["rgo-desktop"],
  },
  {
    name: "rgo-vps",
    flakeAttr: "rgo-vps",
    kind: "nixos-remote",
    description: "Remote NixOS deployment over Tailscale/SSH",
    allowedFrom: ["rgo-desktop"],
    remote: {
      targetHost: "rgo@rgo-vps",
      // local = build on the current NixOS machine, then deploy.
      // target = build on the VPS, equivalent to --build-host rgo@rgo-vps.
      buildHost: "target",
    },
  },
];

export const HOME = Bun.env.HOME ?? "";
export const REPO_DIR = Bun.env.NIX_CONFIG_DIR ?? join(HOME, ".config/home");
export const SECRETS_DIR = join(REPO_DIR, "secrets");
export const AGE_KEY_FILE =
  Bun.env.SOPS_AGE_KEY_FILE ?? join(HOME, ".config/sops/age/keys.txt");
export const OPENROUTER_MODEL = Bun.env.OPENROUTER_MODEL ?? "openrouter/free";
export const DATE_STAMP = new Date().toISOString().slice(0, 10);
