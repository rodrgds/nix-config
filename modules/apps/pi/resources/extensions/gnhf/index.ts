import { spawn } from "node:child_process";
import { readFile, readdir, stat } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STOP_WHEN =
  "The requested objective is fully implemented, all relevant verification passes, and there are no known remaining requirements or blockers.";

const STATUS_KEY = "gnhf";
const WIDGET_KEY = "gnhf";
const POLL_INTERVAL_MS = 1500;

interface WorktreeEntry {
  branch?: string;
  path?: string;
}

interface WorktreeCreateResult {
  action?: string;
  branch?: string;
  path?: string;
}

interface RunState {
  child: ReturnType<typeof spawn> | null;
  cancelCount: number;
}

function stripAnsi(text: string): string {
  // eslint-disable-next-line no-control-regex
  return text.replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "");
}

function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50);
}

function findWorktree(
  entries: WorktreeEntry[],
  branch: string,
): WorktreeEntry | undefined {
  return entries.find((entry) => entry.branch === branch);
}

export default function (pi: ExtensionAPI) {
  const state: RunState = {
    child: null,
    cancelCount: 0,
  };

  async function runGit(
    ctx: { cwd: string },
    args: string[],
  ): Promise<string> {
    const result = await pi.exec("git", args, { cwd: ctx.cwd });
    return result.stdout.trim();
  }

  async function runWtList(cwd: string): Promise<WorktreeEntry[]> {
    const result = await pi.exec("wt", ["list", "--format", "json", "-y"], {
      cwd,
    });
    try {
      return JSON.parse(result.stdout) as WorktreeEntry[];
    } catch {
      return [];
    }
  }

  async function latestRunDir(worktreePath: string): Promise<string | null> {
    const runsRoot = join(worktreePath, ".gnhf", "runs");
    let entries;
    try {
      entries = await readdir(runsRoot, { withFileTypes: true });
    } catch {
      return null;
    }

    let latest: string | null = null;
    let latestMtime = -1;

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const candidate = join(runsRoot, entry.name);
      try {
        const info = await stat(candidate);
        if (info.mtimeMs > latestMtime) {
          latestMtime = info.mtimeMs;
          latest = candidate;
        }
      } catch {
        // Run directory may disappear mid-poll; ignore.
      }
    }

    return latest;
  }

  async function readProgress(
    worktreePath: string,
  ): Promise<{ iteration: number; commits: number; summary: string } | null> {
    const runDir = await latestRunDir(worktreePath);
    if (!runDir) return null;

    let iteration = 0;
    let summary = "";

    try {
      const notes = await readFile(join(runDir, "notes.md"), "utf-8");
      const summaries = notes.match(/^\*\*Summary:\*\* (.+)$/gm);
      if (summaries?.length) {
        summary = summaries[summaries.length - 1].replace(
          /^\*\*Summary:\*\* /,
          "",
        );
      }
    } catch {
      // Notes may not exist yet.
    }

    try {
      const runEntries = await readdir(runDir, { withFileTypes: true });
      const numbers = runEntries
        .map((entry) => entry.name.match(/^iteration-(\d+)\.jsonl$/))
        .filter((match): match is RegExpMatchArray => match !== null)
        .map((match) => Number.parseInt(match[1], 10));
      iteration = numbers.length > 0 ? Math.max(...numbers) : 0;
    } catch {
      // Run directory may disappear mid-poll; ignore.
    }

    let commits = 0;
    try {
      const baseCommit = (
        await readFile(join(runDir, "base-commit"), "utf-8")
      ).trim();
      const result = await pi.exec(
        "git",
        ["rev-list", "--count", `${baseCommit}..HEAD`],
        { cwd: worktreePath },
      );
      commits = Number.parseInt(result.stdout.trim(), 10) || 0;
    } catch {
      // Base commit or git may be briefly unavailable during reset.
    }

    return { iteration, commits, summary };
  }

  function spawnGnhf(
    worktreePath: string,
    objective: string,
  ): Promise<{ code: number | null; errorTail: string }> {
    return new Promise((resolve) => {
      const child = spawn(
        "gnhf",
        [
          objective,
          "--agent",
          "pi",
          "--current-branch",
          "--stop-when",
          STOP_WHEN,
        ],
        {
          cwd: worktreePath,
          detached: process.platform !== "win32",
          stdio: ["ignore", "ignore", "pipe"],
        },
      );

      state.child = child;

      let errorTail = "";
      child.stderr?.on("data", (chunk: Buffer) => {
        errorTail = (errorTail + chunk.toString()).slice(-4000);
      });

      child.on("close", (code) => {
        state.child = null;
        resolve({ code, errorTail: stripAnsi(errorTail).trim() });
      });

      child.on("error", () => {
        state.child = null;
        resolve({ code: null, errorTail: stripAnsi(errorTail).trim() });
      });
    });
  }

  pi.registerCommand("gnhf", {
    description: "Run an autonomous GNHF coding loop in an isolated Worktrunk worktree",
    async handler(args, ctx) {
      const objective = args.trim();
      if (!objective) {
        ctx.ui.notify("Usage: /gnhf <objective>", "error");
        return;
      }

      if (!ctx.hasUI) {
        ctx.ui.notify("The /gnhf command requires an interactive Pi session.", "error");
        return;
      }

      const repoRoot = await runGit(ctx, ["rev-parse", "--show-toplevel"]);
      if (!repoRoot) {
        ctx.ui.notify("Not inside a Git repository.", "error");
        return;
      }

      const currentBranch = await runGit(ctx, ["branch", "--show-current"]);
      const baseLabel = currentBranch
        ? `current worktree (${currentBranch})`
        : "current worktree (detached HEAD)";

      const baseChoice = await ctx.ui.select("GNHF base branch", [
        "main (default branch)",
        baseLabel,
      ]);
      if (!baseChoice) {
        ctx.ui.notify("GNHF cancelled.", "info");
        return;
      }

      const useMain = baseChoice.startsWith("main");
      const baseRef = useMain ? "^" : "@";

      const branch = `gnhf/${slugify(objective)}`;

      let entries = await runWtList(repoRoot);
      let existing = findWorktree(entries, branch);
      let worktreePath: string | undefined = existing?.path;

      ctx.ui.setStatus(STATUS_KEY, `GNHF · ${branch} · preparing worktree`);

      if (!worktreePath) {
        const created = await pi.exec(
          "wt",
          [
            "switch",
            "--create",
            branch,
            "--base",
            baseRef,
            "--no-cd",
            "--format",
            "json",
            "-y",
          ],
          { cwd: repoRoot },
        );

        if (created.code !== 0) {
          ctx.ui.setStatus(STATUS_KEY, undefined);
          ctx.ui.notify(
            `Worktrunk failed to create ${branch}: ${stripAnsi(created.stderr).trim()}`,
            "error",
          );
          return;
        }

        try {
          const parsed = JSON.parse(created.stdout) as WorktreeCreateResult;
          worktreePath = parsed.path;
        } catch {
          entries = await runWtList(repoRoot);
          worktreePath = findWorktree(entries, branch)?.path;
        }
      } else {
        const switched = await pi.exec(
          "wt",
          ["switch", branch, "--no-cd", "--format", "json", "-y"],
          { cwd: repoRoot },
        );
        if (switched.code !== 0) {
          ctx.ui.setStatus(STATUS_KEY, undefined);
          ctx.ui.notify(
            `Worktrunk failed to select ${branch}: ${stripAnsi(switched.stderr).trim()}`,
            "error",
          );
          return;
        }
      }

      if (!worktreePath) {
        ctx.ui.setStatus(STATUS_KEY, undefined);
        ctx.ui.notify(`Could not resolve worktree path for ${branch}.`, "error");
        return;
      }

      ctx.ui.setStatus(STATUS_KEY, `GNHF · ${branch} · working`);

      const renderProgress = async () => {
        const progress = await readProgress(worktreePath);
        const lines = [`GNHF · ${branch}`];
        if (progress) {
          lines.push(
            `iteration ${progress.iteration} · ${progress.commits} commits · working`,
          );
          if (progress.summary) {
            lines.push(`last: ${progress.summary.slice(0, 120)}`);
          }
        } else {
          lines.push("starting autonomous loop...");
        }
        ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
      };

      await renderProgress();

      const pollTimer = setInterval(() => {
        void renderProgress();
      }, POLL_INTERVAL_MS);
      pollTimer.unref?.();

      const result = await spawnGnhf(worktreePath, objective);

      clearInterval(pollTimer);
      await renderProgress();

      ctx.ui.setStatus(STATUS_KEY, undefined);
      ctx.ui.setWidget(WIDGET_KEY, undefined);

      if (result.code === 0) {
        ctx.ui.notify(`GNHF finished: ${branch}`, "info");
      } else {
        const detail = result.errorTail ? `: ${result.errorTail.slice(0, 300)}` : "";
        ctx.ui.notify(
          `GNHF stopped on ${branch} (exit ${result.code ?? "unknown"})${detail}`,
          "warning",
        );
      }

      ctx.ui.notify(`Review with: wt switch ${branch}`, "info");
    },
  });

  pi.registerShortcut("ctrl+alt+g", {
    description: "Interrupt the running /gnhf loop",
    handler: async (ctx) => {
      if (!state.child?.pid) {
        ctx.ui.notify("No /gnhf run is active.", "info");
        return;
      }

      state.cancelCount += 1;

      if (state.cancelCount === 1) {
        process.kill(state.child.pid, "SIGINT");
        ctx.ui.notify(
          "GNHF stop requested. Press again to force-stop.",
          "warning",
        );
        return;
      }

      try {
        process.kill(-state.child.pid, "SIGTERM");
      } catch {
        state.child.kill("SIGTERM");
      }
      ctx.ui.notify("GNHF force-stop requested.", "error");
    },
  });

  pi.on("session_shutdown", () => {
    if (state.child?.pid) {
      try {
        process.kill(-state.child.pid, "SIGTERM");
      } catch {
        state.child?.kill("SIGTERM");
      }
      state.child = null;
    }
  });
}
