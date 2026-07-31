import { DATE_STAMP, HOME, HOST_ALIASES, REPO_DIR, TARGETS } from "./config";
import { commandExists, runCapture } from "./command";
import { join, pathExists, readText } from "./fs";
import type { PlatformKind, Target } from "./types";

export async function detectPlatform(): Promise<PlatformKind> {
  const uname = (
    await runCapture("uname", ["-s"], { cwd: "/", check: false })
  ).trim();

  if (uname === "Darwin") return "darwin";
  if (uname === "Linux") return "linux";
  return "other";
}

export async function isNixOS(platform: PlatformKind): Promise<boolean> {
  return platform === "linux" && (await pathExists("/etc/NIXOS"));
}

export async function detectHost(): Promise<string> {
  const explicit = Bun.env.NIX_REBUILD_HOST;
  if (explicit) return HOST_ALIASES[explicit] ?? explicit;

  const raw = (
    await runCapture("hostname", ["-s"], {
      check: false,
      cwd: HOME || "/",
    })
  ).trim();

  const cleaned = raw.replace(/\.local$/, "");
  return HOST_ALIASES[cleaned] ?? cleaned;
}

export async function allowedTargetsFor(
  currentHost: string,
  platform: PlatformKind,
): Promise<Target[]> {
  const nixos = await isNixOS(platform);

  return TARGETS.filter((target) => {
    if (!target.allowedFrom.includes(currentHost)) return false;
    if (target.kind === "darwin") return platform === "darwin";
    if (target.kind === "nixos") return nixos;
    if (target.kind === "nixos-remote") return nixos;
    return false;
  });
}

export async function parseFlakeInputs(): Promise<string[]> {
  const flakePath = join(REPO_DIR, "flake.nix");
  const lines = (await readText(flakePath)).split("\n");
  const inputs: string[] = [];

  let inInputs = false;
  let depth = 0;

  for (const line of lines) {
    if (!inInputs && /^\s*inputs\s*=\s*\{/.test(line)) {
      inInputs = true;
      depth = 1;
      continue;
    }

    if (!inInputs) continue;

    if (depth === 1) {
      const match = line.match(/^\s*([A-Za-z0-9_.-]+)(?:\.url)?\s*=/);
      const name = match?.[1]?.replace(/\.url$/, "");
      if (name) inputs.push(name);
    }

    const opens = (line.match(/\{/g) ?? []).length;
    const closes = (line.match(/\}/g) ?? []).length;
    depth += opens - closes;

    if (depth <= 0) break;
  }

  return [...new Set(inputs)];
}

export async function defaultCommitMessage(target: Target): Promise<string> {
  const generation = await readGeneration(target);
  if (generation) return `${target.name}: generation ${generation}`;
  return `${target.name}: rebuild ${DATE_STAMP}`;
}

async function readGeneration(target: Target): Promise<string | null> {
  try {
    if (target.kind === "darwin") {
      const output = await runCapture("darwin-rebuild", ["--list-generations"], {
        check: false,
      });
      const current = output
        .split("\n")
        .find((line) => /\bcurrent\b/.test(line));
      return current?.match(/^\s*(\d+)/)?.[1] ?? null;
    }

    if (target.kind === "nixos") {
      const output = await runCapture("nixos-rebuild", ["list-generations"], {
        check: false,
      });
      const current = output.split("\n").find((line) => /\bTrue\b/.test(line));
      return current?.match(/^\s*(\d+)/)?.[1] ?? null;
    }
  } catch {
    return null;
  }

  return null;
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
      {
        check: false,
        cwd: HOME || "/",
      },
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

export type SystemdMajorUpgrade = {
  currentVersion: string;
  targetVersion: string;
};

export async function detectSystemdMajorUpgrade(
  target: Target,
): Promise<SystemdMajorUpgrade | null> {
  if (target.kind !== "nixos") return null;

  const currentOutput = await runCapture("systemctl", ["--version"], {
    check: false,
    cwd: "/",
  });
  const targetVersion = (
    await runCapture(
      "nix",
      [
        "eval",
        "--raw",
        "--impure",
        `path:.#nixosConfigurations.${target.flakeAttr}.config.systemd.package.version`,
      ],
      { check: false, cwd: REPO_DIR },
    )
  ).trim();

  const currentMatch = currentOutput.match(/^systemd\s+(\d+)(?:\.(\d+))?/m);
  const targetMatch = targetVersion.match(/^(\d+)(?:\.(\d+))?/);
  if (!currentMatch || !targetMatch || currentMatch[1] === targetMatch[1]) {
    return null;
  }

  return {
    currentVersion: currentMatch[2]
      ? `${currentMatch[1]}.${currentMatch[2]}`
      : currentMatch[1],
    targetVersion,
  };
}

export function rebuildCommand(
  target: Target,
  nixosMode: "switch" | "boot" = "switch",
): [string, string[]] {
  if (target.kind === "darwin") {
    return withEarlySudo([
      "nh",
      ["darwin", "switch", "path:.", "-H", target.flakeAttr, "--", "--impure"],
    ]);
  }

  if (target.kind === "nixos") {
    return withEarlySudo([
      "nh",
      ["os", nixosMode, "path:.", "-H", target.flakeAttr, "--", "--impure"],
    ]);
  }

  if (!target.remote) {
    throw new Error(`${target.name} is remote but has no remote config.`);
  }

  const args = [
    "switch",
    "--flake",
    `${REPO_DIR}#${target.flakeAttr}`,
    "--target-host",
    target.remote.targetHost,
    "--sudo",
    "--ask-sudo-password",
  ];

  if (target.remote.buildHost === "target") {
    args.push("--build-host", target.remote.targetHost);
  } else if (target.remote.buildHost && target.remote.buildHost !== "local") {
    args.push("--build-host", target.remote.buildHost);
  }

  return withEarlySudo(["nixos-rebuild", args]);
}

function withEarlySudo(command: [string, string[]]): [string, string[]] {
  const [cmd, args] = command;

  return [
    "bash",
    [
      "-lc",
      [
        "sudo -v || exit $?",
        "(",
        "  while true; do",
        "    sudo -n -v >/dev/null 2>&1 || exit 0",
        "    sleep 60",
        "  done",
        ") &",
        "sudo_keepalive=$!",
        'trap \'kill "$sudo_keepalive" >/dev/null 2>&1 || true\' EXIT',
        '"$@"',
      ].join("\n"),
      "rebuild-with-sudo",
      cmd,
      ...args,
    ],
  ];
}
