import { REPO_DIR } from "./config";
import type { CommandOptions, LogCommandOptions } from "./types";

export function quoteShell(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

export function visibleCommand(cmd: string, args: string[]): string {
  return [cmd, ...args].map(quoteShell).join(" ");
}

async function streamToText(stream: ReadableStream<Uint8Array>): Promise<string> {
  return await new Response(stream).text();
}

export async function runCapture(
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
    streamToText(proc.stdout),
    streamToText(proc.stderr),
    proc.exited,
  ]);

  if ((options.check ?? true) && code !== 0) {
    throw new Error(
      `Command failed (${code}): ${visibleCommand(cmd, args)}\n${stderr.trimEnd()}`,
    );
  }

  return stdout.trimEnd();
}

export async function commandExists(command: string): Promise<boolean> {
  const code = await Bun.spawn(
    ["bash", "-lc", `command -v ${quoteShell(command)} >/dev/null 2>&1`],
    {
      stdout: "ignore",
      stderr: "ignore",
    },
  ).exited;

  return code === 0;
}

export async function runInteractive(
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

export async function runLogged(
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
