import { REPO_DIR } from "./config";
import { runCapture } from "./command";

export function truncateMiddle(text: string, max = 120_000): string {
  if (text.length <= max) return text;
  const half = Math.floor(max / 2);
  return `${text.slice(0, half)}\n\n… truncated ${text.length - max} chars …\n\n${text.slice(-half)}`;
}

export async function getGitStatus(): Promise<string> {
  return await runCapture("git", ["status", "--short"], {
    cwd: REPO_DIR,
    check: false,
  });
}

export async function hasGitChanges(): Promise<boolean> {
  return (await getGitStatus()).trim().length > 0;
}

function parsePorcelainZEntries(raw: string): string[] {
  const entries = raw.split("\0").filter(Boolean);
  const files: string[] = [];

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i]!;
    if (entry.length < 4) continue;

    const x = entry[0]!;
    const y = entry[1]!;
    const path = entry.slice(3);

    // In porcelain v1 -z, renames/copies can be represented with an extra path
    // entry. We only need the current path for git add, so skip the next token.
    if ((x === "R" || x === "C") && entries[i + 1]) {
      i += 1;
    }

    const isUntracked = x === "?" && y === "?";
    const hasWorkingTreeChange = y !== " " && y !== "?";

    if (isUntracked || hasWorkingTreeChange) {
      files.push(path);
    }
  }

  return [...new Set(files)].sort();
}

export async function getUnstagedOrUntrackedFiles(): Promise<string[]> {
  const raw = await runCapture(
    "git",
    ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
    { cwd: REPO_DIR, check: false },
  );

  return parsePorcelainZEntries(raw).filter((file) => {
    if (file.includes("_plain")) return false;
    return true;
  });
}

export async function getGitDiffStat(): Promise<string> {
  return await runCapture("git", ["diff", "--stat", "HEAD"], {
    cwd: REPO_DIR,
    check: false,
  });
}

export async function getGitDiff(): Promise<string> {
  const tracked = await runCapture(
    "git",
    [
      "diff",
      "HEAD",
      "--",
      ".",
      ":(exclude)secrets/*_plain*",
      ":(exclude)secrets/**/*_plain*",
    ],
    { cwd: REPO_DIR, check: false },
  );

  const untracked = await runCapture(
    "git",
    [
      "ls-files",
      "--others",
      "--exclude-standard",
      "--",
      ".",
      ":(exclude)secrets/*_plain*",
      ":(exclude)secrets/**/*_plain*",
    ],
    { cwd: REPO_DIR, check: false },
  );

  const untrackedBlock = untracked.trim()
    ? `\n\nUNTRACKED FILES:\n${untracked
        .split("\n")
        .filter(Boolean)
        .map((file) => `  - ${file}`)
        .join("\n")}`
    : "";

  return `${tracked.trimEnd()}${untrackedBlock}`.trimEnd();
}

export async function getDiffForAi(): Promise<string> {
  const status = await getGitStatus();
  const diff = await getGitDiff();

  return truncateMiddle(`STATUS:\n${status}\n\nDIFF:\n${diff}`, 120_000);
}
