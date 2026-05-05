#!/usr/bin/env bun
/// <reference types="bun" />

import {
  BoxRenderable,
  SelectRenderable,
  SelectRenderableEvents,
  TextRenderable,
  TextareaRenderable,
  createCliRenderer,
  type CliRenderer,
  type ParsedKey,
  type SelectOption,
} from "@opentui/core";

type TargetKind = "nixos" | "darwin" | "nixos-remote";
type PlatformKind = "darwin" | "linux" | "other";
type BuildHostMode = "local" | "target" | string;

type Target = {
  name: string;
  flakeAttr: string;
  kind: TargetKind;
  description: string;
  allowedFrom: string[];
  remote?: {
    targetHost: string;
    buildHost?: BuildHostMode;
  };
};

type CommandOptions = {
  cwd?: string;
  env?: Record<string, string | undefined>;
  check?: boolean;
};

type LogCommandOptions = CommandOptions & {
  stdin?: "ignore" | "inherit";
};

type MenuItem<T> = {
  label: string;
  value: T;
  description?: string;
};

type ChecklistItem = {
  label: string;
  value: string;
  description?: string;
};

type SecretFile = {
  name: string;
  encryptedFile: string;
  plainFile: string;
};

type RebuildOptions = {
  updateInputs: string[];
};

const HOST_ALIASES: Record<string, string> = {
  rgopc: "rgo-desktop",
};

const TARGETS: Target[] = [
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
      buildHost: "local",
    },
  },
];

const HOME = Bun.env.HOME ?? "";
const REPO_DIR = Bun.env.NIX_CONFIG_DIR ?? join(HOME, ".config/home");
const SECRETS_DIR = join(REPO_DIR, "secrets");
const AGE_KEY_FILE =
  Bun.env.SOPS_AGE_KEY_FILE ?? join(HOME, ".config/sops/age/keys.txt");
const OPENROUTER_MODEL = Bun.env.OPENROUTER_MODEL ?? "openrouter/free";
const DATE_STAMP = new Date().toISOString().slice(0, 10);

function join(...parts: string[]): string {
  const filtered = parts.filter((part) => part.length > 0);
  if (filtered.length === 0) return "";
  const absolute = filtered[0]!.startsWith("/");
  const joined = filtered
    .map((part, index) => {
      if (index === 0) return part.replace(/\/+$/g, "");
      return part.replace(/^\/+|\/+$/g, "");
    })
    .filter(Boolean)
    .join("/");
  return absolute ? `/${joined.replace(/^\/+/, "")}` : joined;
}

function basename(path: string): string {
  return path.split("/").filter(Boolean).at(-1) ?? path;
}

function stripYaml(path: string): string {
  return basename(path).replace(/\.yaml$/, "");
}

function quoteShell(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

function visibleCommand(cmd: string, args: string[]): string {
  return [cmd, ...args].map(quoteShell).join(" ");
}

function truncateMiddle(text: string, max = 120_000): string {
  if (text.length <= max) return text;
  const half = Math.floor(max / 2);
  return `${text.slice(0, half)}\n\n… truncated ${text.length - max} chars …\n\n${text.slice(-half)}`;
}

async function pathExists(path: string): Promise<boolean> {
  const code = await Bun.spawn(["test", "-e", path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
  return code === 0;
}

async function fileExists(path: string): Promise<boolean> {
  const code = await Bun.spawn(["test", "-f", path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
  return code === 0;
}

async function dirExists(path: string): Promise<boolean> {
  const code = await Bun.spawn(["test", "-d", path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
  return code === 0;
}

async function readText(path: string): Promise<string> {
  return await Bun.file(path).text();
}

async function writeText(path: string, content: string): Promise<void> {
  await Bun.write(path, content);
}

async function deleteFile(path: string): Promise<void> {
  await Bun.spawn(["rm", "-f", path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
}

async function runCapture(
  cmd: string,
  args: string[] = [],
  options: CommandOptions = {},
): Promise<string> {
  const proc = Bun.spawn([cmd, ...args], {
    cwd: options.cwd ?? REPO_DIR,
    env: { ...Bun.env, ...(options.env ?? {}) },
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, code] = await Promise.all([
    proc.stdout.text(),
    proc.stderr.text(),
    proc.exited,
  ]);

  if ((options.check ?? true) && code !== 0) {
    throw new Error(
      `Command failed (${code}): ${visibleCommand(cmd, args)}\n${stderr.trimEnd()}`,
    );
  }

  return stdout.trimEnd();
}

async function commandExists(command: string): Promise<boolean> {
  const code = await Bun.spawn(
    ["bash", "-lc", `command -v ${quoteShell(command)} >/dev/null 2>&1`],
    {
      stdout: "ignore",
      stderr: "ignore",
    },
  ).exited;

  return code === 0;
}

async function detectPlatform(): Promise<PlatformKind> {
  const uname = (
    await runCapture("uname", ["-s"], { cwd: "/", check: false })
  ).trim();

  if (uname === "Darwin") return "darwin";
  if (uname === "Linux") return "linux";
  return "other";
}

async function isNixOS(platform: PlatformKind): Promise<boolean> {
  return platform === "linux" && (await pathExists("/etc/NIXOS"));
}

async function detectHost(): Promise<string> {
  const explicit = Bun.env.NIX_REBUILD_HOST;
  if (explicit) return HOST_ALIASES[explicit] ?? explicit;

  const raw = (
    await runCapture("hostname", ["-s"], {
      capture: true,
      check: false,
      cwd: HOME || "/",
    } as CommandOptions & { capture?: boolean })
  ).trim();

  const cleaned = raw.replace(/\.local$/, "");
  return HOST_ALIASES[cleaned] ?? cleaned;
}

async function allowedTargetsFor(
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

async function parseFlakeInputs(): Promise<string[]> {
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

async function getGitStatus(): Promise<string> {
  return await runCapture("git", ["status", "--short"], {
    cwd: REPO_DIR,
    check: false,
  });
}

async function hasGitChanges(): Promise<boolean> {
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

async function getUnstagedOrUntrackedFiles(): Promise<string[]> {
  const raw = await runCapture(
    "git",
    ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
    { cwd: REPO_DIR, check: false },
  );

  return parsePorcelainZEntries(raw).filter((file) => {
    if (file.includes("_plain")) return false;
    if (file.startsWith("tools/rebuild-wizard/node_modules/")) return false;
    return true;
  });
}

async function stageFiles(files: string[]): Promise<void> {
  if (files.length === 0) return;
  await runCapture("git", ["add", "-A", "--", ...files], {
    cwd: REPO_DIR,
    check: true,
  });
}

async function getGitDiffStat(): Promise<string> {
  return await runCapture("git", ["diff", "--stat", "HEAD"], {
    cwd: REPO_DIR,
    check: false,
  });
}

async function getGitDiff(): Promise<string> {
  const tracked = await runCapture(
    "git",
    [
      "diff",
      "HEAD",
      "--",
      ".",
      ":(exclude)secrets/*_plain*",
      ":(exclude)secrets/**/*_plain*",
      ":(exclude)tools/rebuild-wizard/node_modules/**",
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
      ":(exclude)tools/rebuild-wizard/node_modules/**",
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

async function getDiffForAi(): Promise<string> {
  const status = await getGitStatus();
  const diff = await getGitDiff();

  return truncateMiddle(`STATUS:\n${status}\n\nDIFF:\n${diff}`, 120_000);
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

async function defaultCommitMessage(target: Target): Promise<string> {
  const generation = await readGeneration(target);
  if (generation) return `${target.name}: generation ${generation}`;
  return `${target.name}: rebuild ${DATE_STAMP}`;
}

async function readGeneration(target: Target): Promise<string | null> {
  try {
    if (target.kind === "darwin") {
      const output = await runCapture(
        "darwin-rebuild",
        ["--list-generations"],
        {
          capture: true,
          check: false,
        } as CommandOptions & { capture?: boolean },
      );
      const current = output
        .split("\n")
        .find((line) => /\bcurrent\b/.test(line));
      return current?.match(/^\s*(\d+)/)?.[1] ?? null;
    }

    if (target.kind === "nixos") {
      const output = await runCapture("nixos-rebuild", ["list-generations"], {
        capture: true,
        check: false,
      } as CommandOptions & { capture?: boolean });
      const current = output.split("\n").find((line) => /\bTrue\b/.test(line));
      return current?.match(/^\s*(\d+)/)?.[1] ?? null;
    }
  } catch {
    return null;
  }

  return null;
}

async function notify(
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

function rebuildCommand(target: Target): [string, string[]] {
  if (target.kind === "darwin") {
    return [
      "nh",
      ["darwin", "switch", "path:.", "-H", target.flakeAttr, "--", "--impure"],
    ];
  }

  if (target.kind === "nixos") {
    return [
      "nh",
      ["os", "switch", "path:.", "-H", target.flakeAttr, "--", "--impure"],
    ];
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

  return ["nixos-rebuild", args];
}

async function readOpenRouterApiKey(): Promise<string | null> {
  if (Bun.env.OPENROUTER_API_KEY?.trim())
    return Bun.env.OPENROUTER_API_KEY.trim();
  if (Bun.env.openrouter_api_key?.trim())
    return Bun.env.openrouter_api_key.trim();

  const uid = (
    await runCapture("id", ["-u"], { cwd: "/", check: false })
  ).trim();

  const candidates = [
    Bun.env.XDG_RUNTIME_DIR
      ? join(Bun.env.XDG_RUNTIME_DIR, "secrets/openrouter_api_key")
      : null,
    uid ? `/run/user/${uid}/secrets/openrouter_api_key` : null,
    HOME ? join(HOME, ".config/sops-nix/secrets/openrouter_api_key") : null,
  ].filter(Boolean) as string[];

  for (const candidate of candidates) {
    if (!(await pathExists(candidate))) continue;
    const value = (await readText(candidate)).trim();
    if (value) return value;
  }

  return null;
}

async function generateCommitMessageWithOpenRouter(): Promise<string | null> {
  const apiKey = await readOpenRouterApiKey();
  if (!apiKey) {
    console.error("❌ OpenRouter API key not found in env or config");
    return null;
  }

  const diff = await getDiffForAi();
  if (!diff.trim()) {
    console.error("❌ No diff available for AI commit message");
    return null;
  }

  try {
    const response = await fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://github.com/rodrgds/nix-config",
          "X-Title": "nix-config rebuild wizard",
        },
        body: JSON.stringify({
          model: OPENROUTER_MODEL,
          messages: [
            {
              role: "system",
              content:
                "You write concise git commit messages for a personal NixOS/nix-darwin config. Return exactly one commit subject line, no markdown, no quotes, under 72 characters if possible.",
            },
            {
              role: "user",
              content: `Generate a commit message for this change. Do not mention encrypted secret values.\n\n${diff}`,
            },
          ],
          temperature: 0.2,
          max_tokens: 64,
        }),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(
        `❌ OpenRouter API error (${response.status}): ${errorText}`,
      );
      return null;
    }

    const data = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
      error?: { message?: string };
    };

    if (data.error) {
      console.error(`❌ OpenRouter error: ${data.error.message}`);
      return null;
    }

    const message = data.choices?.[0]?.message?.content
      ?.trim()
      .replace(/^['"]|['"]$/g, "");
    if (!message) {
      console.error("❌ OpenRouter returned empty message");
      return null;
    }

    return message;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`❌ OpenRouter request failed: ${msg}`);
    return null;
  }
}

class App {
  private renderer: CliRenderer;
  private screen: BoxRenderable | null = null;
  private keyHandler: ((key: ParsedKey) => void) | null = null;
  private destroyed = false;

  constructor(renderer: CliRenderer) {
    this.renderer = renderer;
    this.renderer.setBackgroundColor("transparent");

    this.renderer.keyInput.on("keypress", (key: ParsedKey) => {
      if (this.destroyed) return;
      if (key.ctrl && key.name === "c") {
        this.destroy();
        return;
      }
      this.keyHandler?.(key);
    });
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.renderer.destroy();
  }

  private reset(title: string, subtitle?: string): BoxRenderable {
    if (this.screen) {
      this.renderer.root.remove(this.screen.id);
      this.screen = null;
    }

    this.keyHandler = null;

    const screen = new BoxRenderable(this.renderer, {
      id: `screen-${Date.now()}-${Math.random()}`,
      flexDirection: "column",
      width: "100%",
      height: "100%",
      border: true,
      borderStyle: "single",
      borderColor: "#d65d0e",
      title: ` ${title} `,
      titleAlignment: "center",
      backgroundColor: "transparent",
    });

    this.renderer.root.add(screen);
    this.screen = screen;

    if (subtitle) {
      screen.add(
        new TextRenderable(this.renderer, {
          id: `subtitle-${Date.now()}-${Math.random()}`,
          height: Math.max(1, subtitle.split("\n").length),
          content: subtitle,
          fg: "#a89984",
        }),
      );
    }

    return screen;
  }

  async menu<T>(
    title: string,
    subtitle: string,
    options: MenuItem<T>[],
    opts: { allowBack?: boolean; defaultIndex?: number } = {},
  ): Promise<T | null> {
    return await new Promise<T | null>((resolve) => {
      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k to move · Enter to select${opts.allowBack ? " · q/Esc to go back" : ""} · Ctrl+C to quit`,
      );

      const selectOptions: SelectOption[] = options.map((option) => ({
        name: option.label,
        description: option.description ?? "",
        value: option.value,
      }));

      const select = new SelectRenderable(this.renderer, {
        id: `select-${Date.now()}-${Math.random()}`,
        height: "100%",
        options: selectOptions,
        showDescription: true,
        showScrollIndicator: true,
        wrapSelection: true,
        fastScrollStep: 5,
        backgroundColor: "transparent",
        focusedBackgroundColor: "transparent",
        selectedBackgroundColor: "#3c3836",
        textColor: "#ebdbb2",
        selectedTextColor: "#fe8019",
        descriptionColor: "#928374",
        selectedDescriptionColor: "#a89984",
      });

      screen.add(select);

      select.on(
        SelectRenderableEvents.ITEM_SELECTED,
        (_index: number, option: SelectOption) => {
          resolve(option.value as T);
        },
      );

      this.keyHandler = (key) => {
        if (!opts.allowBack) return;
        if (key.name === "q" || key.name === "escape") resolve(null);
      };

      select.focus();

      const defaultIndex = opts.defaultIndex ?? 0;
      for (let i = 0; i < defaultIndex; i++) {
        select.moveDown(1);
      }

      this.renderer.requestRender();
    });
  }

  async confirm(
    title: string,
    message: string,
    defaultYes = false,
  ): Promise<boolean> {
    const yesFirst = defaultYes;
    const options: MenuItem<boolean>[] = yesFirst
      ? [
          { label: "Yes", value: true },
          { label: "No", value: false },
        ]
      : [
          { label: "No", value: false },
          { label: "Yes", value: true },
        ];

    const result = await this.menu(title, message, options);
    return result ?? false;
  }

  async checklist(
    title: string,
    subtitle: string,
    items: ChecklistItem[],
    selectedValues: string[],
    opts: {
      allowBack?: boolean;
      controls?: string;
      onDefault?: () => string[];
      onAll?: () => string[];
      onNone?: () => string[];
    } = {},
  ): Promise<string[] | null> {
    return await new Promise<string[] | null>((resolve) => {
      const selected = new Set(selectedValues);
      let cursor = 0;
      let offset = 0;

      const controls =
        opts.controls ??
        "Space toggles · Enter continues · a all · n none · q/Esc back";

      const screen = this.reset(title, `${subtitle}\n${controls}`);

      const viewport = new BoxRenderable(this.renderer, {
        id: `checklist-viewport-${Date.now()}-${Math.random()}`,
        flexDirection: "column",
        height: "100%",
        width: "100%",
        backgroundColor: "transparent",
      });

      screen.add(viewport);

      const rows: TextRenderable[] = [];
      const visibleHeight = () => Math.max(6, this.renderer.terminalHeight - 6);

      const ensureRows = () => {
        const needed = visibleHeight();
        while (rows.length < needed) {
          const row = new TextRenderable(this.renderer, {
            id: `checklist-row-${Date.now()}-${Math.random()}-${rows.length}`,
            height: 1,
            content: "",
            fg: "#ebdbb2",
          });
          rows.push(row);
          viewport.add(row);
        }

        for (let i = 0; i < rows.length; i++) {
          rows[i]!.visible = i < needed;
        }
      };

      const render = () => {
        ensureRows();

        cursor = Math.max(0, Math.min(cursor, items.length - 1));
        const height = visibleHeight();

        if (cursor < offset) offset = cursor;
        if (cursor >= offset + height) offset = cursor - height + 1;
        offset = Math.max(
          0,
          Math.min(offset, Math.max(0, items.length - height)),
        );

        for (let i = 0; i < rows.length; i++) {
          const row = rows[i]!;
          if (i >= height) {
            row.visible = false;
            continue;
          }

          const index = offset + i;
          const item = items[index];

          if (!item) {
            row.visible = true;
            row.content = "";
            row.fg = "#ebdbb2";
            continue;
          }

          const marker = selected.has(item.value) ? "[x]" : "[ ]";
          const pointer = index === cursor ? ">" : " ";
          const suffix = item.description ? ` — ${item.description}` : "";
          row.visible = true;
          row.content = `${pointer} ${marker} ${item.label}${suffix}`;
          row.fg =
            index === cursor
              ? "#fe8019"
              : selected.has(item.value)
                ? "#b8bb26"
                : "#ebdbb2";
        }

        const last = rows[Math.min(height, rows.length) - 1];
        if (last && items.length > height) {
          const shownTo = Math.min(offset + height, items.length);
          last.content = `${last.content}    [${shownTo}/${items.length}]`;
        }

        this.renderer.requestRender();
      };

      const toggleCurrent = () => {
        const item = items[cursor];
        if (!item) return;
        if (selected.has(item.value)) selected.delete(item.value);
        else selected.add(item.value);
        render();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          cursor += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          cursor -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          cursor += visibleHeight();
          render();
          return;
        }

        if (key.name === "pageup") {
          cursor -= visibleHeight();
          render();
          return;
        }

        if (key.name === "g" && !key.shift && key.raw !== "G") {
          cursor = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          cursor = items.length - 1;
          render();
          return;
        }

        if (key.name === "space" || key.raw === " ") {
          toggleCurrent();
          return;
        }

        if (key.name === "a") {
          selected.clear();
          for (const value of opts.onAll?.() ??
            items.map((item) => item.value)) {
            selected.add(value);
          }
          render();
          return;
        }

        if (key.name === "d" && opts.onDefault) {
          selected.clear();
          for (const value of opts.onDefault()) selected.add(value);
          render();
          return;
        }

        if (key.name === "n") {
          selected.clear();
          for (const value of opts.onNone?.() ?? []) selected.add(value);
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve([...selected]);
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve(null);
        }
      };

      render();
    });
  }

  async input(
    title: string,
    subtitle: string,
    initialValue = "",
  ): Promise<string | null> {
    return await new Promise<string | null>((resolve) => {
      const screen = this.reset(
        title,
        `${subtitle}\nEnter accepts · Esc cancels · Ctrl+C quits`,
      );

      const box = new BoxRenderable(this.renderer, {
        id: `input-box-${Date.now()}-${Math.random()}`,
        border: true,
        borderStyle: "single",
        borderColor: "#928374",
        height: 5,
        width: "100%",
        backgroundColor: "transparent",
      });

      const input = new TextareaRenderable(this.renderer, {
        id: `input-${Date.now()}-${Math.random()}`,
        width: "100%",
        height: 1,
        placeholder: "Commit message",
        placeholderColor: "#928374",
        backgroundColor: "transparent",
        focusedBackgroundColor: "transparent",
        textColor: "#ebdbb2",
        focusedTextColor: "#ebdbb2",
        cursorColor: "#fe8019",
        wrapMode: "none",
        showCursor: true,
      });

      box.add(input);
      screen.add(box);
      input.editBuffer.setText(initialValue);
      input.focus();

      this.keyHandler = (key) => {
        if (key.name === "return" || key.name === "linefeed") {
          key.preventDefault();
          resolve(input.editBuffer.getText().trim());
        }

        if (key.name === "escape") {
          key.preventDefault();
          resolve(null);
        }
      };

      this.renderer.requestRender();
    });
  }

  async scrollText(
    title: string,
    subtitle: string,
    content: string,
    opts: { allowBack?: boolean; enterLabel?: string } = {},
  ): Promise<"enter" | "back"> {
    return await new Promise<"enter" | "back">((resolve) => {
      const lines = content.split("\n");
      let offset = 0;

      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k scroll · PgUp/PgDn fast · ${opts.enterLabel ?? "Enter continue"}${opts.allowBack ? " · q/Esc back" : ""}`,
      );

      const body = new TextRenderable(this.renderer, {
        id: `scroll-${Date.now()}-${Math.random()}`,
        height: "100%",
        content: "",
        fg: "#ebdbb2",
      });

      screen.add(body);

      const render = () => {
        const height = Math.max(8, this.renderer.terminalHeight - 7);
        const maxOffset = Math.max(0, lines.length - height);
        offset = Math.max(0, Math.min(offset, maxOffset));

        const visible = lines.slice(offset, offset + height).join("\n");
        const counter = `\n\n[${Math.min(offset + height, lines.length)}/${lines.length} lines]`;
        body.content = `${visible}${counter}`;
        this.renderer.requestRender();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          offset += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          offset -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          offset += Math.max(8, this.renderer.terminalHeight - 8);
          render();
          return;
        }

        if (key.name === "pageup") {
          offset -= Math.max(8, this.renderer.terminalHeight - 8);
          render();
          return;
        }

        if (key.name === "g" && !key.shift) {
          offset = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          offset = lines.length;
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve("enter");
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve("back");
        }
      };

      render();
    });
  }

  async coloredDiff(
    title: string,
    subtitle: string,
    status: string,
    stat: string,
    diff: string,
    opts: { allowBack?: boolean; enterLabel?: string } = {},
  ): Promise<"enter" | "back"> {
    return await new Promise<"enter" | "back">((resolve) => {
      const lines = [
        "GIT STATUS",
        status.trim() || "No uncommitted changes.",
        "",
        "DIFF STAT",
        stat.trim() ||
          "No tracked diff stat. You may only have untracked files.",
        "",
        "FULL DIFF",
        ...(diff.trim() ? diff.split("\n") : ["No diff."]),
      ];

      let offset = 0;

      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k scroll · PgUp/PgDn fast · g top · G bottom · ${opts.enterLabel ?? "Enter continue"}${opts.allowBack ? " · q/Esc back" : ""}`,
      );

      const viewport = new BoxRenderable(this.renderer, {
        id: `diff-viewport-${Date.now()}-${Math.random()}`,
        flexDirection: "column",
        height: "100%",
        width: "100%",
        backgroundColor: "transparent",
      });

      screen.add(viewport);

      const lineRenderables: TextRenderable[] = [];
      const visibleHeight = () => Math.max(8, this.renderer.terminalHeight - 6);

      const colorForLine = (line: string): string => {
        if (line.startsWith("+") && !line.startsWith("+++")) return "#b8bb26";
        if (line.startsWith("-") && !line.startsWith("---")) return "#fb4934";
        if (line.startsWith("@@")) return "#83a598";
        if (line.startsWith("diff --git")) return "#fe8019";
        if (line.startsWith("index ")) return "#d3869b";
        if (line.startsWith("+++ ") || line.startsWith("--- "))
          return "#fabd2f";
        if (
          line === "GIT STATUS" ||
          line === "DIFF STAT" ||
          line === "FULL DIFF"
        )
          return "#fe8019";
        if (/^\s*[MADRCU?]{1,2}\s+/.test(line)) return "#d3869b";
        return "#ebdbb2";
      };

      const trimLine = (line: string): string => {
        const width = Math.max(20, this.renderer.terminalWidth - 4);
        if (line.length <= width) return line;
        return `${line.slice(0, width - 1)}…`;
      };

      const ensureLineRenderables = () => {
        const needed = visibleHeight();
        while (lineRenderables.length < needed) {
          const line = new TextRenderable(this.renderer, {
            id: `diff-line-${Date.now()}-${Math.random()}-${lineRenderables.length}`,
            height: 1,
            content: "",
            fg: "#ebdbb2",
          });
          lineRenderables.push(line);
          viewport.add(line);
        }

        for (let i = 0; i < lineRenderables.length; i++) {
          lineRenderables[i]!.visible = i < needed;
        }
      };

      const render = () => {
        ensureLineRenderables();

        const height = visibleHeight();
        const maxOffset = Math.max(0, lines.length - height);
        offset = Math.max(0, Math.min(offset, maxOffset));

        for (let i = 0; i < lineRenderables.length; i++) {
          const renderable = lineRenderables[i]!;
          if (i >= height) {
            renderable.visible = false;
            continue;
          }

          const line = lines[offset + i] ?? "";
          renderable.visible = true;
          renderable.content = trimLine(line);
          renderable.fg = colorForLine(line);
        }

        const last =
          lineRenderables[Math.min(height, lineRenderables.length) - 1];
        if (last) {
          const end = Math.min(offset + height, lines.length);
          last.content = `${trimLine(lines[offset + height - 1] ?? "")}    [${end}/${lines.length}]`;
          last.fg = colorForLine(lines[offset + height - 1] ?? "");
        }

        this.renderer.requestRender();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          offset += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          offset -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          offset += Math.max(8, visibleHeight() - 1);
          render();
          return;
        }

        if (key.name === "pageup") {
          offset -= Math.max(8, visibleHeight() - 1);
          render();
          return;
        }

        if (key.name === "g" && !key.shift && key.raw !== "G") {
          offset = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          offset = lines.length;
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve("enter");
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve("back");
        }
      };

      render();
    });
  }

  async logScreen(
    title: string,
    subtitle: string,
    runner: (append: (line: string) => void) => Promise<void>,
  ): Promise<boolean> {
    const screen = this.reset(title, subtitle);
    const body = new TextRenderable(this.renderer, {
      id: `log-${Date.now()}-${Math.random()}`,
      height: "100%",
      content: "",
      fg: "#ebdbb2",
    });

    screen.add(body);

    const lines: string[] = [];
    let done = false;
    let success = false;

    const render = () => {
      const height = Math.max(8, this.renderer.terminalHeight - 6);
      const visible = lines.slice(-height).join("\n");
      const footer = done
        ? success
          ? "\n\nDone. Press Enter to continue."
          : "\n\nFailed. Press Enter to continue."
        : "\n\nRunning…";
      body.content = `${visible}${footer}`;
      this.renderer.requestRender();
    };

    const append = (line: string) => {
      for (const part of line.replace(/\r/g, "").split("\n")) {
        lines.push(part);
      }
      render();
    };

    this.keyHandler = (key) => {
      if (!done) return;
      if (key.name === "return" || key.name === "linefeed") {
        this.keyHandler = null;
      }
    };

    render();

    try {
      await runner(append);
      success = true;
    } catch (error) {
      success = false;
      append("");
      append(error instanceof Error ? error.message : String(error));
    } finally {
      done = true;
      render();
    }

    await new Promise<void>((resolve) => {
      this.keyHandler = (key) => {
        if (key.name === "return" || key.name === "linefeed") resolve();
      };
    });

    return success;
  }

  async externalCommandScreen(
    title: string,
    subtitle: string,
    cmd: string,
    args: string[],
    options: CommandOptions = {},
  ): Promise<boolean> {
    this.reset(
      title,
      [
        subtitle,
        "",
        "The next command needs the real terminal.",
        "OpenTUI will temporarily leave the alternate screen.",
        "When the command finishes, press Enter to return to the wizard.",
      ].join("\n"),
    );

    this.renderer.requestRender();
    await sleep(150);

    const rendererAny = this.renderer as unknown as {
      stop?: () => void;
      start?: () => void;
    };

    try {
      rendererAny.stop?.();
    } catch {
      // Older OpenTUI versions may not expose stop().
    }

    try {
      process.stdin.setRawMode?.(false);
    } catch {
      // Ignore if stdin is not a TTY.
    }

    process.stdout.write("\u001b[0m\u001b[?25h\u001b[?1049l");
    process.stdout.write("\n");
    process.stdout.write(`$ ${visibleCommand(cmd, args)}\n\n`);

    let success = false;

    try {
      await runInteractive(cmd, args, options);
      success = true;
    } catch (error) {
      success = false;
      process.stdout.write("\n");
      process.stdout.write(
        error instanceof Error ? error.message : String(error),
      );
      process.stdout.write("\n");
    }

    process.stdout.write("\nPress Enter to return to the wizard...");
    await new Promise<void>((resolve) => {
      const onData = () => {
        process.stdin.off("data", onData);
        resolve();
      };

      process.stdin.once("data", onData);
    });

    process.stdout.write("\u001b[?1049h\u001b[2J\u001b[H\u001b[?25l");

    try {
      process.stdin.setRawMode?.(true);
    } catch {
      // Ignore if stdin is not a TTY.
    }

    try {
      rendererAny.start?.();
    } catch {
      // If OpenTUI has no resumable start(), the next render still often works.
    }

    this.reset(
      success ? "Command finished" : "Command failed",
      success
        ? "The external command completed successfully."
        : "The external command failed. See the terminal output above.",
    );

    await new Promise<void>((resolve) => {
      this.keyHandler = (key) => {
        if (key.name === "return" || key.name === "linefeed") resolve();
      };
    });

    return success;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function stripAnsiAndControl(text: string): string {
  return (
    text
      // ANSI escape sequences
      .replace(/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g, "")
      // Backspace redraw noise
      .replace(/[^\n]\x08/g, "")
      // Keep tabs/newlines, remove other C0 controls
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
  );
}

async function runInteractive(
  cmd: string,
  args: string[],
  options: CommandOptions = {},
): Promise<number> {
  const proc = Bun.spawn([cmd, ...args], {
    cwd: options.cwd ?? REPO_DIR,
    env: { ...Bun.env, ...(options.env ?? {}) },
    stdin: "inherit",
    stdout: "inherit",
    stderr: "inherit",
  });

  const code = await proc.exited;

  if ((options.check ?? true) && code !== 0) {
    throw new Error(`Command failed (${code}): ${visibleCommand(cmd, args)}`);
  }

  return code;
}

async function runLogged(
  append: (line: string) => void,
  cmd: string,
  args: string[],
  options: LogCommandOptions = {},
): Promise<void> {
  append(`$ ${visibleCommand(cmd, args)}`);

  const proc = Bun.spawn([cmd, ...args], {
    cwd: options.cwd ?? REPO_DIR,
    env: {
      ...Bun.env,
      NO_COLOR: "1",
      CLICOLOR: "0",
      TERM: "dumb",
      ...(options.env ?? {}),
    },
    stdin: options.stdin ?? "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });

  const pump = async (
    stream: ReadableStream<Uint8Array>,
    prefix = "",
  ): Promise<void> => {
    const reader = stream.getReader();
    const decoder = new TextDecoder();

    let buffered = "";

    while (true) {
      const { done, value } = await reader.read();

      if (done) {
        const rest = stripAnsiAndControl(buffered).trimEnd();
        if (rest) {
          for (const line of rest.split("\n")) {
            append(`${prefix}${line}`);
          }
        }
        break;
      }

      const raw = decoder.decode(value, { stream: true });

      // Treat carriage-return progress updates as line replacements.
      // This avoids repeated "building..." / spinner spam as much as possible.
      buffered += raw.replace(/\r(?!\n)/g, "\n");

      const parts = buffered.split("\n");
      buffered = parts.pop() ?? "";

      for (const part of parts) {
        const cleaned = stripAnsiAndControl(part).trimEnd();
        if (cleaned.length > 0) append(`${prefix}${cleaned}`);
      }
    }
  };

  await Promise.all([pump(proc.stdout), pump(proc.stderr)]);
  const code = await proc.exited;

  append(`exit code: ${code}`);
  append("");

  if ((options.check ?? true) && code !== 0) {
    throw new Error(`Command failed (${code}): ${visibleCommand(cmd, args)}`);
  }
}

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
  const defaultInputs = inputs.filter((input) => input !== "nixpkgs-davinci");

  const selectedInputs = await app.checklist(
    "Flake inputs",
    "Choose inputs to update before rebuilding. Leave all unchecked to skip flake updates.",
    inputs.map((input) => ({
      label: input,
      value: input,
      description:
        input === "nixpkgs-davinci"
          ? "Pinned heavyweight input; excluded from default set."
          : "Included in default update set.",
    })),
    [],
    {
      allowBack: true,
      controls:
        "Space toggles · Enter continues · d default set · a all · n none · q/Esc back",
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
  const subtitle = `Target: ${target.name}. Rebuild runs in real terminal for nh/sudo/password support.`;

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

async function runSopsCapture(args: string[]): Promise<string> {
  const [cmd, prefix] = await sopsCommand();
  return await runCapture(cmd, [...prefix, ...args], {
    cwd: REPO_DIR,
    env: { SOPS_AGE_KEY_FILE: AGE_KEY_FILE },
  });
}

async function runSopsLogged(
  append: (line: string) => void,
  args: string[],
): Promise<void> {
  const [cmd, prefix] = await sopsCommand();
  await runLogged(append, cmd, [...prefix, ...args], {
    cwd: REPO_DIR,
    env: { SOPS_AGE_KEY_FILE: AGE_KEY_FILE },
  });
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
    const [cmd, prefix] = await sopsCommand();

    await app.externalCommandScreen(
      "sops edit",
      `${secret.name} - sops and $EDITOR need the real terminal`,
      cmd,
      [...prefix, secret.encryptedFile],
      {
        cwd: SECRETS_DIR,
        env: { SOPS_AGE_KEY_FILE: AGE_KEY_FILE },
        check: false,
      },
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

async function cleanupWizard(app: App): Promise<void> {
  const action = await app.menu(
    "Cleanup tools",
    "Choose one cleanup action.",
    [
      {
        label: "nh clean all --keep 5",
        value: "nh-keep-5",
        description: "Keep a few generations.",
      },
      {
        label: "nh clean all",
        value: "nh-clean-all",
        description: "More aggressive nh cleanup.",
      },
      {
        label: "nix store optimise",
        value: "optimise",
        description: "Hard-link identical store paths.",
      },
      {
        label: "nix-collect-garbage -d",
        value: "gc-delete",
        description: "Delete old generations and collect garbage.",
      },
      {
        label: "Show GC roots",
        value: "roots",
        description: "Inspect why paths are kept alive.",
      },
    ] as MenuItem<
      "nh-keep-5" | "nh-clean-all" | "optimise" | "gc-delete" | "roots"
    >[],
    { allowBack: true },
  );

  if (!action) return;

  await app.logScreen("Cleanup", action, async (append) => {
    if (action === "nh-keep-5") {
      await runLogged(append, "nh", ["clean", "all", "--keep", "5"], {
        cwd: REPO_DIR,
      });
    } else if (action === "nh-clean-all") {
      await runLogged(append, "nh", ["clean", "all"], { cwd: REPO_DIR });
    } else if (action === "optimise") {
      await runLogged(append, "nix", ["store", "optimise"], { cwd: REPO_DIR });
    } else if (action === "gc-delete") {
      await runLogged(append, "nix-collect-garbage", ["-d"], {
        cwd: REPO_DIR,
      });
    } else if (action === "roots") {
      await runLogged(append, "nix-store", ["--gc", "--print-roots"], {
        cwd: REPO_DIR,
        check: false,
      });
    }
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
});

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
