import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STOP_WHEN =
  "The requested objective is fully implemented, all relevant verification passes, and there are no known remaining requirements or blockers.";

const STATUS_KEY = "gnhf";
const WIDGET_KEY = "gnhf";
const MAX_LOG_LINES = 20;

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

  function spawnGnhf(
    worktreePath: string,
    objective: string,
    onLine: (line: string) => void,
  ): Promise<{ code: number | null }> {
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
          stdio: ["ignore", "pipe", "pipe"],
        },
      );

      state.child = child;

      let buffer = "";
      const handleChunk = (chunk: Buffer) => {
        buffer += chunk.toString();
        const parts = buffer.split(/\r?\n/);
        buffer = parts.pop() ?? "";
        for (const part of parts) {
          const cleaned = stripAnsi(part).trimEnd();
          if (cleaned.trim().length > 0) {
            onLine(cleaned);
          }
        }
      };

      child.stdout?.on("data", handleChunk);
      child.stderr?.on("data", handleChunk);

      child.on("close", (code) => {
        const tail = stripAnsi(buffer).trimEnd();
        if (tail.trim().length > 0) {
          onLine(tail);
        }
        state.child = null;
        resolve({ code });
      });

      child.on("error", () => {
        state.child = null;
        resolve({ code: null });
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

      let logLines: string[] = [];

      const renderWidget = () => {
        const header = `GNHF · ${branch}`;
        const lines =
          logLines.length > 0
            ? [header, ...logLines.slice(-MAX_LOG_LINES)]
            : [header, "starting autonomous loop..."];
        ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
      };

      renderWidget();

      const result = await spawnGnhf(worktreePath, objective, (line) => {
        logLines.push(line);
        renderWidget();
      });

      ctx.ui.setStatus(STATUS_KEY, undefined);
      ctx.ui.setWidget(WIDGET_KEY, undefined);

      if (result.code === 0) {
        ctx.ui.notify(`GNHF finished: ${branch}`, "info");
      } else {
        ctx.ui.notify(
          `GNHF stopped on ${branch} (exit ${result.code ?? "unknown"}).`,
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
