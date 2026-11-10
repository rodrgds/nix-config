import { existsSync } from "node:fs";
import { FLAKE_REF, HOME, HOST_ALIASES, TARGETS } from "./config";
import { commandExists, runCapture } from "./command";
import type { Action, PlatformKind, Target } from "./types";

export const USAGE = `Usage:
  rebuild                 rebuild this machine (no-op when nothing changed)
  rebuild update          update flake inputs and the 9Router catalog, rebuild,
                          then refresh npm CLIs, skills and Homebrew in the background
  rebuild vps             deploy rgo-vps with deploy-rs (automatic rollback)
  rebuild secrets [name]  edit secrets/<name>.yaml with sops (default: secrets)

Target flags also work: ${TARGETS.map(({ cliFlag }) => cliFlag).join(", ")}, --update.`;

export function parseArgs(args: string[]): Action {
  const [first, ...rest] = args;
  if (first === undefined) return { kind: "rebuild" };
  if (["help", "--help", "-h"].includes(first) && rest.length === 0) {
    return { kind: "help" };
  }
  if (["update", "--update"].includes(first) && rest.length === 0) {
    return { kind: "update" };
  }
  if (first === "secrets" && rest.length <= 1) {
    return { kind: "secrets", file: rest[0] };
  }
  if (first === "vps" && rest.length === 0) {
    return { kind: "rebuild", target: "rgo-vps" };
  }
  const target = TARGETS.find(({ cliFlag }) => cliFlag === first);
  if (target && rest.length === 0) {
    return { kind: "rebuild", target: target.name };
  }
  throw new Error(`Unknown arguments: ${args.join(" ")}\n\n${USAGE}`);
}

export async function detectPlatform(): Promise<PlatformKind> {
  const uname = (
    await runCapture("uname", ["-s"], { cwd: "/", check: false })
  ).trim();
  if (uname === "Darwin") return "darwin";
  if (uname === "Linux") return "linux";
  return "other";
}

export async function detectHost(): Promise<string> {
  const explicit = Bun.env.NIX_REBUILD_HOST;
  if (explicit) return HOST_ALIASES[explicit] ?? explicit;
  const raw = (
    await runCapture("hostname", ["-s"], { check: false, cwd: HOME || "/" })
  ).trim();
  const cleaned = raw.replace(/\.local$/, "");
  return HOST_ALIASES[cleaned] ?? cleaned;
}

export function allowedTargetsFor(
  currentHost: string,
  platform: PlatformKind,
): Target[] {
  const nixos = platform === "linux" && existsSync("/etc/NIXOS");
  return TARGETS.filter((target) => {
    if (!target.allowedFrom.includes(currentHost)) return false;
    if (target.kind === "darwin") return platform === "darwin";
    if (target.kind === "nixos") return nixos;
    return platform === "darwin" || nixos;
  });
}

const NIXOS_STORE_SPACE_ARGS = [
  "--option",
  "min-free",
  String(8 * 1024 * 1024 * 1024),
  "--option",
  "max-free",
  String(16 * 1024 * 1024 * 1024),
];

// Builds without root, so an unchanged system never asks for a password.
export function buildCommand(target: Target, outLink: string): [string, string[]] {
  const platform = target.kind === "darwin" ? "darwin" : "os";
  return [
    "nh",
    [
      platform,
      "build",
      FLAKE_REF,
      "-H",
      target.name,
      "-o",
      outLink,
      ...(target.kind === "nixos" ? NIXOS_STORE_SPACE_ARGS : []),
    ],
  ];
}

// nix-darwin's own switch: point the system profile at the build, then
// activate it as root (darwin-rebuild switch does exactly these two steps).
export function darwinActivateCommand(system: string): [string, string[]] {
  return [
    "sudo",
    [
      "/bin/sh",
      "-c",
      'set -e; "$1/sw/bin/nix-env" -p /nix/var/nix/profiles/system --set "$1"; exec "$1/activate"',
      "rebuild-activate",
      system,
    ],
  ];
}

// NixOS keeps nh for activation: the build is already cached, and nh runs
// switch-to-configuration the way nixos-rebuild does.
export function nixosSwitchCommand(
  target: Target,
  mode: "switch" | "boot",
): [string, string[]] {
  return [
    "nh",
    [
      "os",
      mode,
      FLAKE_REF,
      "-H",
      target.name,
      "--show-activation-logs",
      ...NIXOS_STORE_SPACE_ARGS,
    ],
  ];
}

export function deployCommand(
  target: Target,
  currentHost: string,
): [string, string[]] {
  const args = ["run", `${FLAKE_REF}#deploy-rs`, "--", "--skip-checks"];
  if (target.remoteBuildFrom?.includes(currentHost)) args.push("--remote-build");
  args.push(`${FLAKE_REF}#${target.name}`);
  return ["nix", args];
}

// Activation is skipped only when the build is already live and the last
// activation of it succeeded, so a failed switch is retried next time.
export function needsActivation(
  built: string,
  current: string | null,
  lastActivated: string | null,
): boolean {
  return built !== current || built !== lastActivated;
}

// A live PID 1 re-exec across systemd major versions can hang, so such
// generations become the boot default instead of switching live.
export function systemdMajorChange(
  currentSystemd: string | null,
  builtSystemd: string | null,
): { from: string; to: string } | null {
  const major = (path: string | null) => path?.match(/-systemd-(\d+)/)?.[1];
  const from = major(currentSystemd);
  const to = major(builtSystemd);
  return from && to && from !== to ? { from, to } : null;
}

export function postRebuildHealthCommand(
  target: Target,
  currentHost: string,
): [string, string[]] | null {
  if (target.kind !== "darwin" || currentHost !== target.name) return null;
  return ["/run/current-system/sw/bin/rgo-laptop-health", []];
}

// Refresh the vendor-updated tools in the background after `rebuild update`.
export function backgroundUpdateCommands(
  platform: PlatformKind,
  uid: string,
): [string, string[]][] {
  if (platform === "darwin") {
    return ["pt.rgo.update-javascript-toolchain", "pt.rgo.homebrew-upgrade"].map(
      (label) => ["launchctl", ["kickstart", `gui/${uid}/${label}`]],
    );
  }
  return [
    [
      "systemctl",
      ["--user", "start", "--no-block", "update-javascript-toolchain.service"],
    ],
  ];
}

export async function notify(
  platform: PlatformKind,
  title: string,
  message: string,
): Promise<void> {
  if (platform === "darwin") {
    await runCapture(
      "osascript",
      [
        "-e",
        `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`,
      ],
      { check: false, cwd: HOME || "/" },
    );
    return;
  }
  if (await commandExists("notify-send")) {
    await runCapture("notify-send", [title, message], {
      check: false,
      cwd: HOME || "/",
    });
  }
}
