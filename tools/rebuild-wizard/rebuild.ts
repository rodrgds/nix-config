#!/usr/bin/env bun
// Applies this repo to the current machine; see USAGE in targets.ts.
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CURRENT_SYSTEM, HOME, REPO_DIR, STATE_DIR } from "./config";
import { runCapture, runInteractive } from "./command";
import {
  assertNoPlainSecrets,
  editSecrets,
  exposeNewFilesToFlake,
} from "./secrets";
import {
  USAGE,
  allowedTargetsFor,
  backgroundUpdateCommands,
  buildCommand,
  darwinActivateCommand,
  deployCommand,
  detectHost,
  detectPlatform,
  needsActivation,
  nixosSwitchCommand,
  notify,
  parseArgs,
  postRebuildHealthCommand,
  systemdMajorChange,
} from "./targets";
import type { CommandOptions, PlatformKind, Target } from "./types";

// Notifications only help when the terminal was likely left unattended.
const NOTIFY_AFTER_SECONDS = 30;

function realpathOrNull(path: string): string | null {
  try {
    return realpathSync(path);
  } catch {
    return null;
  }
}

function readOrNull(path: string): string | null {
  try {
    return readFileSync(path, "utf8").trim() || null;
  } catch {
    return null;
  }
}

async function run(
  [cmd, args]: [string, string[]],
  phase: string,
  options: CommandOptions = {},
): Promise<void> {
  const code = await runInteractive(cmd, args, {
    cwd: REPO_DIR,
    check: false,
    phase,
    ...options,
  });
  if (code !== 0) throw new Error(`${phase} failed with exit code ${code}.`);
}

async function rebuildLocal(target: Target, currentHost: string): Promise<void> {
  mkdirSync(STATE_DIR, { recursive: true });
  const outLink = join(STATE_DIR, `${target.name}-system`);
  const stamp = join(STATE_DIR, `${target.name}-activated`);

  await run(buildCommand(target, outLink), "evaluation and build", {
    retryNixDaemonCrash: true,
  });
  const built = realpathSync(outLink);
  if (!needsActivation(built, realpathOrNull(CURRENT_SYSTEM), readOrNull(stamp))) {
    console.log(`\n${target.name} is already running this configuration.`);
    return;
  }

  if (target.kind === "darwin") {
    await run(darwinActivateCommand(built), "activation");
  } else {
    const upgrade = systemdMajorChange(
      realpathOrNull(join(CURRENT_SYSTEM, "systemd")),
      realpathOrNull(join(built, "systemd")),
    );
    if (upgrade) {
      console.log(
        `systemd ${upgrade.from} -> ${upgrade.to}: installing a boot generation instead of switching live. Reboot to finish.`,
      );
    }
    await run(nixosSwitchCommand(target, upgrade ? "boot" : "switch"), "activation", {
      retryNixDaemonCrash: true,
    });
  }
  writeFileSync(stamp, `${realpathOrNull(CURRENT_SYSTEM) ?? ""}\n`);

  const health = postRebuildHealthCommand(target, currentHost);
  if (health) await run(health, "post-rebuild health");
}

const NINE_ROUTER_MODELS_URL = "http://rgo-nas:20128/v1/models";
const COMBOS_FILE = "modules/shared/9router/combos.json";

async function refreshNineRouterCombos(): Promise<void> {
  const uid = (await runCapture("id", ["-u"], { cwd: "/", check: false })).trim();
  const apiKey = [
    Bun.env.XDG_RUNTIME_DIR && join(Bun.env.XDG_RUNTIME_DIR, "secrets/nine_router_api_key"),
    uid && `/run/user/${uid}/secrets/nine_router_api_key`,
    HOME && join(HOME, ".config/sops-nix/secrets/nine_router_api_key"),
  ]
    .filter((path): path is string => Boolean(path))
    .map(readOrNull)
    .find(Boolean);
  if (!apiKey) {
    console.log("9Router API key not found; keeping the committed combos.");
    return;
  }
  try {
    const response = await fetch(NINE_ROUTER_MODELS_URL, {
      headers: { Authorization: `Bearer ${apiKey}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = (await response.json()) as {
      data?: { id: string; owned_by: string }[];
    };
    const combos = (body.data ?? [])
      .filter((model) => model.owned_by === "combo")
      .map((model) => ({ alias: model.id, displayName: model.id }))
      .sort((a, b) => a.alias.localeCompare(b.alias));
    if (combos.length === 0) {
      console.log("9Router reports no combos; keeping the committed combos.");
      return;
    }
    writeFileSync(
      join(REPO_DIR, COMBOS_FILE),
      `${JSON.stringify({ models: combos }, null, 2)}\n`,
    );
    console.log(`9Router combos: ${combos.map((c) => c.alias).join(", ")}.`);
  } catch (error) {
    console.log(
      `9Router fetch failed (${error instanceof Error ? error.message : error}); keeping the committed combos.`,
    );
  }
}

async function startBackgroundUpdates(platform: PlatformKind): Promise<void> {
  const uid = (await runCapture("id", ["-u"], { cwd: "/", check: false })).trim();
  for (const [cmd, args] of backgroundUpdateCommands(platform, uid)) {
    await runCapture(cmd, args, { cwd: "/", check: false });
  }
  console.log(
    `Updating npm CLIs and skills${platform === "darwin" ? " and Homebrew apps" : ""} in the background.`,
  );
}

async function offerUpdateCommit(): Promise<void> {
  const changed = (
    await runCapture("git", ["status", "--porcelain", "--", "flake.lock", COMBOS_FILE], {
      check: false,
    })
  )
    .split("\n")
    .filter(Boolean)
    .map((line) => line.slice(3));
  if (changed.length === 0 || !process.stdin.isTTY) return;
  const answer = prompt(`Commit ${changed.join(" and ")}? [Y/n]`) ?? "";
  if (/^n/i.test(answer.trim())) return;
  await assertNoPlainSecrets("commit");
  const date = new Date().toISOString().slice(0, 10);
  await run(["git", ["commit", "-m", `flake: update inputs ${date}`, "--", ...changed]], "commit");
}

async function main(): Promise<void> {
  const action = parseArgs(Bun.argv.slice(2));
  if (action.kind === "help") {
    console.log(USAGE);
    return;
  }
  if (action.kind === "secrets") {
    process.exitCode = await editSecrets(action.file);
    return;
  }

  const startedAt = performance.now();
  const platform = await detectPlatform();
  const currentHost = await detectHost();
  const allowed = allowedTargetsFor(currentHost, platform);
  const targetName = (action.kind === "rebuild" && action.target) || currentHost;
  const target = allowed.find(({ name }) => name === targetName);
  if (!target) {
    throw new Error(
      `${targetName} cannot be rebuilt from ${currentHost} on ${platform}. Allowed: ${allowed.map(({ name }) => name).join(", ") || "none"} (set NIX_REBUILD_HOST if the hostname is wrong).`,
    );
  }

  try {
    await assertNoPlainSecrets("rebuild");
    await exposeNewFilesToFlake();

    if (action.kind === "update") {
      await run(["nix", ["flake", "update", "--flake", REPO_DIR]], "flake input update");
      await refreshNineRouterCombos();
    }

    if (target.kind === "nixos-remote") {
      await run(deployCommand(target, currentHost), "deploy", {
        retryNixDaemonCrash: true,
      });
    } else {
      await rebuildLocal(target, currentHost);
    }

    if (action.kind === "update") {
      await startBackgroundUpdates(platform);
      await offerUpdateCommit();
    }
  } catch (error) {
    if ((performance.now() - startedAt) / 1000 > NOTIFY_AFTER_SECONDS) {
      await notify(platform, "Rebuild failed", target.name);
    }
    throw error;
  }

  const seconds = (performance.now() - startedAt) / 1000;
  console.log(`${target.name} done in ${seconds.toFixed(1)}s.`);
  if (seconds > NOTIFY_AFTER_SECONDS) {
    await notify(platform, "Rebuild finished", target.name);
  }
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
