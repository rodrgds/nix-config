#!/usr/bin/env bun
/// <reference types="bun" />

import { createCliRenderer } from "@opentui/core";

import { App } from "./app";
import { generateCommitMessageWithOpenRouter } from "./ai";
import {
  AGE_KEY_FILE,
  OPENROUTER_MODEL,
  REPO_DIR,
  SECRETS_DIR,
} from "./config";
import { commandExists, runCapture, runLogged } from "./command";
import {
  basename,
  deleteFile,
  dirExists,
  join,
  pathExists,
  writeText,
} from "./fs";
import {
  getGitDiff,
  getGitDiffStat,
  getGitStatus,
  getUnstagedOrUntrackedFiles,
  hasGitChanges,
} from "./git";
import {
  allowedTargetsFor,
  defaultCommitMessage,
  detectHost,
  detectPlatform,
  isNixOS,
  notify,
  parseFlakeInputs,
  rebuildCommand,
} from "./targets";
import type {
  CommandOptions,
  MenuItem,
  PlatformKind,
  RebuildOptions,
  SecretFile,
  Target,
} from "./types";

async function showGitDiff(app: App): Promise<void> {
  const status = await getGitStatus();
  const stat = await getGitDiffStat();
  const diff = await getGitDiff();

  await app.coloredDiff("Git diff", `Repo: ${REPO_DIR}`, status, stat, diff, {
    allowBack: true,
    enterLabel: "Enter continue",
  });
}

async function maybeStageBeforeInitialDiff(app: App): Promise<void> {
  const files = await getUnstagedOrUntrackedFiles();
  if (files.length === 0) return;

  const list = files.map((file) => `  - ${file}`).join("\n");
  await app.scrollText(
    "Unstaged / untracked files",
    "These are modified-but-not-staged or untracked files. Plaintext secrets and node_modules are excluded.",
    list,
    { allowBack: false, enterLabel: "Enter continue" },
  );

  const shouldStage = await app.confirm(
    "Stage files?",
    `Stage these ${files.length} unstaged/untracked file${files.length === 1 ? "" : "s"} before showing the initial diff?`,
    false,
  );

  if (!shouldStage) return;

  await app.logScreen(
    "Stage files",
    "Running git add -A -- <selected files>",
    async (append) => {
      await runLogged(append, "git", ["add", "-A", "--", ...files], {
        cwd: REPO_DIR,
      });
    },
  );
}

async function chooseTarget(
  app: App,
  currentHost: string,
  allowed: Target[],
): Promise<Target | null> {
  if (allowed.length === 0) {
    await app.scrollText(
      "No allowed targets",
      `Current host: ${currentHost}`,
      "No rebuild targets are allowed from this host.\n\nSet NIX_REBUILD_HOST=rgo-desktop if hostname detection is wrong.",
      { allowBack: true },
    );
    return null;
  }

  return await app.menu(
    "Target",
    `Current host: ${currentHost}`,
    allowed.map((target) => ({
      label: target.name,
      value: target,
      description: target.description,
    })),
    { allowBack: true },
  );
}

async function chooseRebuildOptions(app: App): Promise<RebuildOptions | null> {
  const inputs = await parseFlakeInputs();
  const defaultInputs: string[] = [];

  const selectedInputs = await app.checklist(
    "Flake inputs",
    "Choose inputs to update before rebuilding. Default is no input updates.",
    inputs.map((input) => ({
      label: input,
      value: input,
      description:
        input === "nixpkgs-davinci"
          ? "Pinned heavyweight input; update manually only."
          : "Manual update only; default rebuild does not update inputs.",
    })),
    [],
    {
      allowBack: true,
      controls:
        "Space toggles · Enter continues · d default none · a all · n none · q/Esc back",
      onDefault: () => defaultInputs,
      onAll: () => inputs,
      onNone: () => [],
    },
  );

  if (selectedInputs === null) return null;

  return {
    updateInputs: selectedInputs,
  };
}

async function listPlainSecretFiles(): Promise<string[]> {
  if (!(await dirExists(SECRETS_DIR))) return [];

  const output = await runCapture(
    "find",
    [
      "-L",
      SECRETS_DIR,
      "(",
      "-type",
      "f",
      "-o",
      "-type",
      "l",
      ")",
      "(",
      "-name",
      "*_plain*.yaml",
      "-o",
      "-name",
      "*_plain*.yml",
      ")",
    ],
    { cwd: REPO_DIR, check: false },
  );

  return output.split("\n").filter(Boolean).sort();
}

async function runPreparationAndRebuild(
  app: App,
  platform: PlatformKind,
  target: Target,
  options: RebuildOptions,
): Promise<boolean> {
  const prepared = await app.logScreen(
    "Preparation log",
    `Target: ${target.name}. Running flake updates, statix, and nixfmt.`,
    async (append) => {
      if (options.updateInputs.length > 0) {
        await runLogged(
          append,
          "nix",
          ["flake", "update", ...options.updateInputs, "--flake", REPO_DIR],
          { cwd: REPO_DIR },
        );
      } else {
        append("Skipping flake input updates.");
        append("");
      }

      if (await commandExists("statix")) {
        await runLogged(append, "statix", ["check", "."], {
          cwd: REPO_DIR,
          check: false,
        });
      } else {
        append("statix not found; skipping.");
        append("");
      }

      if (await commandExists("nixfmt")) {
        await runLogged(
          append,
          "bash",
          [
            "-lc",
            "find . -name '*.nix' -not -path './tools/rebuild-wizard/node_modules/*' -exec nixfmt {} +",
          ],
          { cwd: REPO_DIR, check: false },
        );
      } else {
        append("nixfmt not found; skipping.");
        append("");
      }
    },
  );

  if (!prepared) return false;

  const [cmd, args] = rebuildCommand(target);
  const subtitle = `Target: ${target.name}. Local rebuilds ask for sudo immediately and keep it fresh while building.`;

  const success = await app.externalCommandScreen(
    "Rebuild",
    subtitle,
    cmd,
    args,
    { cwd: REPO_DIR },
  );

  if (success) {
    await notify(platform, "Rebuild successful", target.name);
  }

  return success;
}

async function commitFlow(app: App, target: Target): Promise<void> {
  if (!(await hasGitChanges())) {
    await app.scrollText(
      "Commit",
      "No changes",
      "There are no changes to commit.",
      { allowBack: false },
    );
    return;
  }

  const plainSecrets = await listPlainSecretFiles();
  if (plainSecrets.length > 0) {
    await app.scrollText(
      "Commit blocked",
      "Plaintext secrets found",
      [
        "Refusing to commit while plaintext secret files exist:",
        "",
        ...plainSecrets.map((file) => `  - ${file}`),
        "",
        "Encrypt or remove them first.",
      ].join("\n"),
      { allowBack: false },
    );
    return;
  }

  const wantsCommit = await app.confirm(
    "Commit changes?",
    "Review the final diff, then choose a commit message?",
    false,
  );

  if (!wantsCommit) return;

  await showGitDiff(app);

  const fallback = await defaultCommitMessage(target);
  const mode = await app.menu(
    "Commit message",
    "Choose the commit message source.",
    [
      {
        label: `Use default: ${fallback}`,
        value: "default",
        description: "Fastest option.",
      },
      {
        label: "Generate with OpenRouter",
        value: "ai",
        description: `Uses ${OPENROUTER_MODEL} and your openrouter_api_key secret/env.`,
      },
      {
        label: "Write manually",
        value: "manual",
        description: "Opens a one-line input inside the TUI.",
      },
      {
        label: "Skip commit",
        value: "skip",
      },
    ] as MenuItem<"default" | "ai" | "manual" | "skip">[],
    { allowBack: true },
  );

  if (!mode || mode === "skip") return;

  let message = fallback;

  if (mode === "ai") {
    const suggested = await app.logScreen(
      "OpenRouter",
      "Generating commit message from git diff.",
      async (append) => {
        append(`Model: ${OPENROUTER_MODEL}`);
        const generated = await generateCommitMessageWithOpenRouter();
        if (!generated) {
          append("No commit message returned. Falling back to default.");
          return;
        }
        message = generated;
        append(`Suggested: ${message}`);
      },
    );

    if (!suggested) message = fallback;

    const edited = await app.input(
      "Edit commit message",
      "Review or edit the generated message.",
      message,
    );
    if (edited === null) return;
    message = edited || fallback;
  }

  if (mode === "manual") {
    const manual = await app.input(
      "Manual commit message",
      "Write one commit subject line.",
      fallback,
    );
    if (manual === null) return;
    message = manual || fallback;
  }

  const committed = await app.logScreen(
    "Commit",
    `Message: ${message}`,
    async (append) => {
      await runLogged(append, "git", ["add", "-A"], { cwd: REPO_DIR });
      await runLogged(append, "git", ["commit", "-m", message], {
        cwd: REPO_DIR,
      });
    },
  );

  if (!committed) return;

  const push = await app.confirm(
    "Push",
    "Push the new commit now? This is never automatic.",
    false,
  );

  if (!push) return;

  await app.logScreen("Push", "Running git push.", async (append) => {
    await runLogged(append, "git", ["push"], { cwd: REPO_DIR });
  });
}

async function rebuildWizard(
  app: App,
  platform: PlatformKind,
  currentHost: string,
  allowed: Target[],
): Promise<void> {
  await maybeStageBeforeInitialDiff(app);
  await showGitDiff(app);

  const target = await chooseTarget(app, currentHost, allowed);
  if (!target) return;

  const options = await chooseRebuildOptions(app);
  if (!options) return;

  const confirmed = await app.confirm(
    "Confirm rebuild",
    `Run statix, nixfmt, then rebuild ${target.name}?`,
    true,
  );
  if (!confirmed) return;

  const success = await runPreparationAndRebuild(
    app,
    platform,
    target,
    options,
  );
  if (!success) {
    await notify(platform, "Rebuild failed", target.name);
    return;
  }

  await commitFlow(app, target);
}

async function sopsCommand(): Promise<[string, string[]]> {
  if (await commandExists("sops")) return ["sops", []];
  return ["nix", ["shell", "nixpkgs#sops", "-c", "sops"]];
}

async function secretFiles(): Promise<SecretFile[]> {
  const roots = [...new Set([SECRETS_DIR, join(REPO_DIR, "secrets")])];

  const existingRoots: string[] = [];
  for (const root of roots) {
    if (await dirExists(root)) existingRoots.push(root);
  }

  if (existingRoots.length === 0) return [];

  const found = new Set<string>();

  for (const root of existingRoots) {
    const output = await runCapture(
      "find",
      [
        "-L",
        root,
        "(",
        "-type",
        "f",
        "-o",
        "-type",
        "l",
        ")",
        "(",
        "-name",
        "*.yaml",
        "-o",
        "-name",
        "*.yml",
        ")",
      ],
      { cwd: REPO_DIR, check: false },
    );

    for (const file of output.split("\n").filter(Boolean)) {
      const base = basename(file);
      if (base.includes("_plain")) continue;
      if (base === ".sops.yaml" || base === ".sops.yml") continue;
      found.add(file);
    }
  }

  return [...found].sort().map((file) => {
    const base = basename(file).replace(/\.(yaml|yml)$/, "");
    const dir = file.split("/").slice(0, -1).join("/") || SECRETS_DIR;
    const ext = file.endsWith(".yml") ? "yml" : "yaml";

    return {
      name: base,
      encryptedFile: file,
      plainFile: join(dir, `${base}_plain.${ext}`),
    };
  });
}

async function sopsInvocation(
  args: string[],
  options: CommandOptions = {},
): Promise<{ cmd: string; args: string[]; options: CommandOptions }> {
  const [cmd, prefix] = await sopsCommand();
  return {
    cmd,
    args: [...prefix, ...args],
    options: {
      cwd: REPO_DIR,
      ...options,
      env: { SOPS_AGE_KEY_FILE: AGE_KEY_FILE, ...(options.env ?? {}) },
    },
  };
}

async function runSopsCapture(args: string[]): Promise<string> {
  const command = await sopsInvocation(args);
  return await runCapture(command.cmd, command.args, command.options);
}

async function secretsWizard(app: App): Promise<void> {
  const files = await secretFiles();

  if (files.length === 0) {
    await app.scrollText(
      "Secrets",
      SECRETS_DIR,
      "No encrypted YAML files found.",
      { allowBack: true },
    );
    return;
  }

  const secret = await app.menu(
    "Secrets file",
    `Directory: ${SECRETS_DIR}`,
    files.map((file) => ({
      label: file.name,
      value: file,
      description: basename(file.encryptedFile),
    })),
    { allowBack: true },
  );

  if (!secret) return;

  const action = await app.menu(
    "Secrets action",
    secret.name,
    [
      {
        label: "Decrypt to *_plain.yaml",
        value: "decrypt-file",
        description:
          "Writes plaintext locally; git commit is blocked until encrypted/removed.",
      },
      {
        label: "Encrypt *_plain.yaml and delete it",
        value: "encrypt",
        description:
          "Reads the plaintext file, writes encrypted YAML, then removes plaintext.",
      },
      {
        label: "View decrypted output inside TUI",
        value: "view",
        description: "Useful for inspection. Avoid screenshots/recording.",
      },
      {
        label: "Edit directly with sops",
        value: "edit",
        description:
          "External editor action; this is the only action that cannot stay fully inside TUI.",
      },
      {
        label: "List plaintext leftovers",
        value: "list-plain",
      },
    ] as MenuItem<
      "decrypt-file" | "encrypt" | "view" | "edit" | "list-plain"
    >[],
    { allowBack: true },
  );

  if (!action) return;

  if (action === "decrypt-file") {
    const overwrite =
      !(await pathExists(secret.plainFile)) ||
      (await app.confirm(
        "Overwrite plaintext?",
        `${secret.plainFile} already exists. Overwrite?`,
        false,
      ));

    if (!overwrite) return;

    await app.logScreen("Decrypt", secret.name, async (append) => {
      append(`Decrypting to ${secret.plainFile}`);
      const decrypted = await runSopsCapture([
        "--decrypt",
        secret.encryptedFile,
      ]);
      await writeText(secret.plainFile, decrypted);
      await runLogged(append, "chmod", ["600", secret.plainFile], {
        cwd: SECRETS_DIR,
        check: false,
      });
      append("Done.");
    });
    return;
  }

  if (action === "encrypt") {
    if (!(await pathExists(secret.plainFile))) {
      await app.scrollText(
        "Encrypt",
        secret.name,
        `Plain file not found:\n${secret.plainFile}`,
        { allowBack: false },
      );
      return;
    }

    const ok = await app.confirm(
      "Encrypt",
      `Encrypt ${secret.plainFile} into ${secret.encryptedFile} and delete plaintext?`,
      true,
    );

    if (!ok) return;

    await app.logScreen("Encrypt", secret.name, async (append) => {
      append(`Encrypting ${secret.plainFile}`);
      const encrypted = await runSopsCapture(["--encrypt", secret.plainFile]);
      await writeText(secret.encryptedFile, encrypted);
      await deleteFile(secret.plainFile);
      append("Encrypted and removed plaintext file.");
    });
    return;
  }

  if (action === "view") {
    const decrypted = await runSopsCapture(["--decrypt", secret.encryptedFile]);
    await app.scrollText(
      "Decrypted secrets",
      `${secret.name} · output is not written to disk`,
      decrypted,
      { allowBack: false },
    );
    return;
  }

  if (action === "edit") {
    const command = await sopsInvocation([secret.encryptedFile], {
      cwd: SECRETS_DIR,
      check: false,
    });

    await app.externalCommandScreen(
      "sops edit",
      `${secret.name} - sops and $EDITOR need the real terminal`,
      command.cmd,
      command.args,
      command.options,
    );
    return;
  }

  if (action === "list-plain") {
    const leftovers = await listPlainSecretFiles();
    await app.scrollText(
      "Plaintext leftovers",
      SECRETS_DIR,
      leftovers.length ? leftovers.join("\n") : "No plaintext leftovers found.",
      { allowBack: false },
    );
  }
}

type CleanupAction = {
  label: string;
  value: string;
  description?: string;
  command: [cmd: string, args: string[]];
  options?: CommandOptions;
};

const CLEANUP_ACTIONS: CleanupAction[] = [
  {
    label: "nh clean all --keep 5",
    value: "nh-keep-5",
    description: "Keep a few generations.",
    command: ["nh", ["clean", "all", "--keep", "5"]],
  },
  {
    label: "nh clean all",
    value: "nh-clean-all",
    description: "More aggressive nh cleanup.",
    command: ["nh", ["clean", "all"]],
  },
  {
    label: "nix store optimise",
    value: "optimise",
    description: "Hard-link identical store paths.",
    command: ["nix", ["store", "optimise"]],
  },
  {
    label: "nix-collect-garbage -d",
    value: "gc-delete",
    description: "Delete old generations and collect garbage.",
    command: ["nix-collect-garbage", ["-d"]],
  },
  {
    label: "Show GC roots",
    value: "roots",
    description: "Inspect why paths are kept alive.",
    command: ["nix-store", ["--gc", "--print-roots"]],
    options: { check: false },
  },
];

async function cleanupWizard(app: App): Promise<void> {
  const action = await app.menu(
    "Cleanup tools",
    "Choose one cleanup action.",
    CLEANUP_ACTIONS.map(({ label, value, description }) => ({
      label,
      value,
      description,
    })),
    { allowBack: true },
  );

  if (!action) return;

  const selected = CLEANUP_ACTIONS.find((item) => item.value === action);
  if (!selected) return;

  await app.logScreen("Cleanup", selected.value, async (append) => {
    const [cmd, args] = selected.command;
    await runLogged(append, cmd, args, {
      cwd: REPO_DIR,
      ...(selected.options ?? {}),
    });
  });
}

async function mainLoop(app: App): Promise<void> {
  if (!(await pathExists(join(REPO_DIR, "flake.nix")))) {
    await app.scrollText(
      "Error",
      "Missing flake.nix",
      `No flake.nix found at:\n${REPO_DIR}\n\nSet NIX_CONFIG_DIR to override.`,
      { allowBack: false },
    );
    return;
  }

  const platform = await detectPlatform();
  const nixos = await isNixOS(platform);
  const currentHost = await detectHost();
  const allowed = await allowedTargetsFor(currentHost, platform);

  while (true) {
    const action = await app.menu(
      "rgo nix rebuild wizard",
      [
        `Repo: ${REPO_DIR}`,
        `Host: ${currentHost}`,
        `System: ${platform}${nixos ? " / NixOS" : ""}`,
        `Allowed targets: ${allowed.map((target) => target.name).join(", ") || "none"}`,
      ].join("\n"),
      [
        {
          label: "Rebuild / update wizard",
          value: "rebuild",
          description:
            "Diff → target → flake inputs → lint/format → rebuild → commit/push.",
        },
        {
          label: "Show git diff",
          value: "diff",
          description:
            "Status, diff stat, full diff, and untracked files inside the TUI.",
        },
        {
          label: "Secrets manager",
          value: "secrets",
          description:
            "Decrypt/encrypt/view sops YAML files with plaintext safety checks.",
        },
        {
          label: "Cleanup tools",
          value: "cleanup",
          description:
            "nh clean, nix store optimise, garbage collection, GC roots.",
        },
        {
          label: "Quit",
          value: "quit",
        },
      ] as MenuItem<"rebuild" | "diff" | "secrets" | "cleanup" | "quit">[],
    );

    if (action === "quit" || action === null) return;
    if (action === "diff") await showGitDiff(app);
    if (action === "rebuild") {
      await rebuildWizard(app, platform, currentHost, allowed);
    }
    if (action === "secrets") await secretsWizard(app);
    if (action === "cleanup") await cleanupWizard(app);
  }
}

const renderer = await createCliRenderer({
  exitOnCtrlC: false,
  targetFps: 30,
  useAlternateScreen: true,
} as Parameters<typeof createCliRenderer>[0] & { useAlternateScreen: boolean });

const app = new App(renderer);
renderer.start();

try {
  await mainLoop(app);
} catch (error) {
  await app.scrollText(
    "Unhandled error",
    "The wizard caught an exception.",
    error instanceof Error ? (error.stack ?? error.message) : String(error),
    { allowBack: false },
  );
} finally {
  app.destroy();
}
