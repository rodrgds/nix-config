import { afterEach, describe, expect, test } from "bun:test";
import { existsSync, realpathSync } from "node:fs";
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
  const sudoMarker = join(root, "sudo-called");
  for (const [name, body] of Object.entries({
    uname: "printf 'Darwin\\n'",
    id: "printf '9999999999\\n'",
    osascript: "exit 0",
    nix: 'printf "%s\\n" "$*" >> "$NIX_TEST_MARKER"; exit 73',
    // Builds "succeed" by linking the running system, as an unchanged build would.
    nh: [
      'while [ "$#" -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done',
      'ln -sfn "$(readlink -f /run/current-system)" "$out"',
    ].join("\n"),
    sudo: 'printf "%s\\n" "$*" >> "$SUDO_TEST_MARKER"; exit 75',
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
    SUDO_TEST_MARKER: sudoMarker,
    XDG_STATE_HOME: join(home, "state"),
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
  return { home, repo, env, marker, sudoMarker, command };
}

async function direct(f: Awaited<ReturnType<typeof fixture>>, args = ["--vps"]) {
  const proc = Bun.spawn([...f.command, ...args], {
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

test("encrypted-only and missing secrets directories reach the deploy command", async () => {
  const f = await fixture();
  for (const missing of [false, true]) {
    if (missing) await rm(join(f.repo, "secrets"), { recursive: true });
    const result = await direct(f);
    expect(result.code).toBe(1);
    expect(result.output).toContain("deploy failed with exit code 73");
    expect(await Bun.file(f.marker).text()).toContain(".#deploy-rs");
    await rm(f.marker);
  }
});

test("a plain rebuild with a plaintext secret stops before building", async () => {
  const f = await fixture();
  await Bun.write(join(f.repo, "secrets/dummy_plain.txt"), "DUMMY ONLY\n");
  const result = await direct(f, []);
  expect(result.code).toBe(1);
  expect(result.output).toContain("Refusing to rebuild");
  expect(result.output).not.toContain("DUMMY ONLY");
  expect(await Bun.file(join(f.home, "state/rebuild/rgo-laptop-system")).exists()).toBe(false);
});

describe.skipIf(!existsSync("/run/current-system"))("local laptop rebuild", () => {
  test("activates a build that was never activated by the wizard", async () => {
    const f = await fixture();
    const result = await direct(f, []);
    expect(result.code).toBe(1);
    expect(result.output).toContain("activation failed with exit code 75");
    expect(await Bun.file(f.sudoMarker).text()).toContain("/nix/var/nix/profiles/system");
  });

  test("an unchanged system finishes without asking for root", async () => {
    const f = await fixture();
    await mkdir(join(f.home, "state/rebuild"), { recursive: true });
    await Bun.write(
      join(f.home, "state/rebuild/rgo-laptop-activated"),
      `${realpathSync("/run/current-system")}\n`,
    );
    const result = await direct(f, []);
    expect(result.output).toContain("already running this configuration");
    expect(result.code).toBe(0);
    expect(await Bun.file(f.sudoMarker).exists()).toBe(false);
  });
});
