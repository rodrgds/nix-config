import { join } from "node:path";
import type { Target } from "./types";

export const HOST_ALIASES: Record<string, string> = {
  rgopc: "rgo-desktop",
};

export const TARGETS: Target[] = [
  {
    name: "rgo-laptop",
    cliFlag: "--laptop",
    kind: "darwin",
    allowedFrom: ["rgo-laptop"],
  },
  {
    name: "rgo-desktop",
    cliFlag: "--desktop",
    kind: "nixos",
    allowedFrom: ["rgo-desktop"],
  },
  {
    name: "rgo-vps",
    cliFlag: "--vps",
    kind: "nixos-remote",
    allowedFrom: ["rgo-laptop", "rgo-desktop"],
    // The laptop cannot build x86_64-linux, so the VPS builds its own closure.
    remoteBuildFrom: ["rgo-laptop"],
  },
];

export const HOME = Bun.env.HOME ?? "";
export const REPO_DIR = Bun.env.NIX_CONFIG_DIR ?? join(HOME, ".config/home");
// Git flake: Nix copies only files Git knows about (tracked, modified, or
// intent-to-add), never ignored files, node_modules, or .git itself.
export const FLAKE_REF = ".";
export const SECRETS_DIR = join(REPO_DIR, "secrets");
export const AGE_KEY_FILE =
  Bun.env.SOPS_AGE_KEY_FILE ?? join(HOME, ".config/sops/age/keys.txt");
// The last built system (a GC root) and the last successfully activated one.
export const STATE_DIR = join(
  Bun.env.XDG_STATE_HOME ?? join(HOME, ".local/state"),
  "rebuild",
);
export const CURRENT_SYSTEM = "/run/current-system";
