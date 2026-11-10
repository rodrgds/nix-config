import { expect, test } from "bun:test";
import { tmpdir } from "node:os";

test("interactive phase reports a failed command before returning its exit status", async () => {
  const child = Bun.spawn(
    [
      process.execPath,
      "-e",
      `import { runInteractive } from ${JSON.stringify(`${import.meta.dir}/command.ts`)};
     const code = await runInteractive(process.execPath, ["-e", "await Bun.sleep(40); process.exit(31)"],
       { cwd: ${JSON.stringify(tmpdir())}, check: false, phase: "build and activation" });
     process.exit(code);`,
    ],
    { cwd: tmpdir(), stdout: "pipe", stderr: "pipe" },
  );
  const [output, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  expect(stderr).toBe("");
  expect(code).toBe(31);
  expect(output).toMatch(/\[timing\] build and activation: [\d.]+s/);
});
