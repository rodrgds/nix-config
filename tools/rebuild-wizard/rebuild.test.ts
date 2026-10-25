import { afterEach, expect, test } from "bun:test";
import { chmod, mkdir, mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];
afterEach(async () => {
  await Promise.all(
    fixtures.splice(0).map((path) => rm(path, { recursive: true, force: true })),
  );
});

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "rebuild-preflight-"));
  fixtures.push(root);
  const bin = join(root, "bin");
  const repo = join(root, "repo");
  const home = join(root, "home");
  await Promise.all([bin, repo, home].map((path) => mkdir(path)));
  await mkdir(join(repo, "secrets"));
  await Bun.write(join(repo, "flake.nix"), "{ outputs = { self }: {}; }\n");
  await Bun.write(
    join(repo, ".gitignore"),
    "secrets/*_plain*\nsecrets/**/*_plain*\n",
  );
  await Bun.write(
    join(repo, "secrets/dummy.yaml"),
    "encrypted fixture placeholder\n",
  );

  const marker = join(root, "nix-called");
  for (const [name, body] of Object.entries({
    uname: "printf 'Darwin\\n'",
    id: "printf '9999999999\\n'",
    osascript: "exit 0",
    nix: 'printf "%s\\n" "$*" >> "$NIX_TEST_MARKER"; exit 73',
    nh: "exit 74",
    sudo: "exit 75",
  })) {
    const path = join(bin, name);
    await Bun.write(path, `#!/bin/sh\n${body}\n`);
    await chmod(path, 0o755);
  }
  const env = {
    ...Bun.env,
    PATH: `${bin}:${Bun.env.PATH}`,
    HOME: home,
    XDG_RUNTIME_DIR: home,
    SOPS_AGE_KEY_FILE: join(home, "dummy-age-key"),
    NIX_CONFIG_DIR: repo,
    NIX_REBUILD_HOST: "rgo-laptop",
    NIX_TEST_MARKER: marker,
    TERM: "xterm-256color",
  };
  for (const args of [
    ["init", "-q"],
    ["add", "flake.nix", ".gitignore", "secrets/dummy.yaml"],
  ]) {
    expect(
      await Bun.spawn(["git", ...args], {
        cwd: repo,
        env,
        stdout: "ignore",
        stderr: "pipe",
      }).exited,
    ).toBe(0);
  }
  const command = [process.execPath, join(import.meta.dir, "rebuild.ts")];
  return { repo, env, marker, command };
}

async function direct(f: Awaited<ReturnType<typeof fixture>>) {
  const proc = Bun.spawn([...f.command, "--vps"], {
    cwd: f.repo,
    env: f.env,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  return { output: stdout + stderr, code };
}

for (const name of [
  "dummy_plain.yaml",
  "nested/dummy_plain",
  "nested/dummy_plain.json",
]) {
  test(`direct rebuild rejects ignored secrets/${name} before Nix`, async () => {
    const f = await fixture();
    await mkdir(join(f.repo, "secrets/nested"), { recursive: true });
    await Bun.write(join(f.repo, "secrets", name), "DUMMY ONLY\n");
    const ignored = Bun.spawn(["git", "check-ignore", `secrets/${name}`], {
      cwd: f.repo,
      env: f.env,
      stdout: "ignore",
    });
    expect(await ignored.exited).toBe(0);
    const result = await direct(f);
    expect(await Bun.file(f.marker).exists()).toBe(false);
    expect(result.code).toBe(1);
    expect(result.output).toContain("Refusing to rebuild");
    expect(result.output).toContain(name);
    expect(result.output).not.toContain("DUMMY ONLY");
  });
}

test("direct rebuild fails closed when the secrets root cannot be resolved", async () => {
  const f = await fixture();
  await rm(join(f.repo, "secrets"), { recursive: true });
  await symlink("secrets", join(f.repo, "secrets"));
  const result = await direct(f);
  expect(await Bun.file(f.marker).exists()).toBe(false);
  expect(result.code).toBe(1);
  expect(result.output).toContain("Cannot scan plaintext secrets");
});

test.skipIf(process.getuid?.() === 0)(
  "direct rebuild fails closed on an unreadable nested directory",
  async () => {
    const f = await fixture();
    const restricted = join(f.repo, "secrets/restricted");
    await mkdir(restricted, { mode: 0o000 });
    try {
      const result = await direct(f);
      expect(await Bun.file(f.marker).exists()).toBe(false);
      expect(result.code).toBe(1);
      expect(result.output).toContain("Cannot scan plaintext secrets");
    } finally {
      await chmod(restricted, 0o700);
    }
  },
);

test("encrypted-only and missing secrets directories reach the rebuild command", async () => {
  const f = await fixture();
  for (const missing of [false, true]) {
    if (missing) await rm(join(f.repo, "secrets"), { recursive: true });
    const result = await direct(f);
    expect(result.output).toContain("Rebuild failed with exit code 73");
    expect(await Bun.file(f.marker).text()).toContain("path:.#deploy-rs");
    await rm(f.marker);
  }
});

test("interactive rebuild blocks before preparation and keeps the Secrets manager accessible", async () => {
  const f = await fixture();
  await Bun.write(join(f.repo, "secrets/dummy_plain.txt"), "DUMMY ONLY\n");
  let output = "";
  const terminal = new Bun.Terminal({
    cols: 160,
    rows: 40,
    data(_terminal, data) {
      output += new TextDecoder()
        .decode(data)
        .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
    },
  });
  const proc = Bun.spawn(f.command, { cwd: f.repo, env: f.env, terminal });
  async function waitFor(text: string) {
    const deadline = Date.now() + 5000;
    while (!output.includes(text) && !(await Bun.file(f.marker).exists())) {
      if (Date.now() > deadline) {
        throw new Error(`Missing screen: ${text}\n${output.slice(-4000)}`);
      }
      await Bun.sleep(20);
    }
    expect(await Bun.file(f.marker).exists()).toBe(false);
    expect(output).toContain(text);
  }
  async function enterScreen(keys: string, text: string) {
    output = "";
    terminal.write(keys);
    await waitFor(text);
  }
  try {
    await waitFor("rgo nix rebuild wizard");
    await enterScreen("\r", "Git diff");
    await enterScreen("\r", "Current host:");
    await enterScreen("j\r", "Flake inputs");
    await enterScreen("\r", "Run statix, nixfmt, then rebuild");
    await enterScreen("\r", "Refusing to rebuild");
    expect(output).toContain("dummy_plain.txt");
    expect(output).not.toContain("DUMMY ONLY");
    await enterScreen("\r", "rgo nix rebuild wizard");
    await enterScreen("jj\r", "Directory:");
    await enterScreen("\r", "External editor action");
    expect(output.replace(/\s/g, "")).toContain("Editdirectlywithsops");
  } finally {
    proc.kill();
    await proc.exited;
    terminal.close();
  }
}, 15000);
