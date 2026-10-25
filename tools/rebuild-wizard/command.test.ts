import { expect, test } from "bun:test";
import { tmpdir } from "node:os";

import { runLogged } from "./command";

for (const code of [0, 31]) {
  test(`logged phase reports elapsed subprocess time and preserves exit ${code}`, async () => {
    const lines: string[] = [];
    const command = runLogged(
      (line) => lines.push(line),
      process.execPath,
      [
        "-e",
        `await Bun.sleep(40); console.log("fixture output"); process.exit(${code})`,
      ],
      { cwd: tmpdir(), phase: "cross-system evaluation" },
    );
    if (code === 0) await command;
    else await expect(command).rejects.toThrow("Command failed (31)");

    expect(lines).toContain("fixture output");
    expect(lines).toContain(`exit code: ${code}`);
    const timing = lines.find((line) =>
      line.startsWith("[timing] cross-system evaluation:"),
    );
    expect(timing).toBeDefined();
    const seconds = Number(timing!.match(/: ([\d.]+)s$/)?.[1]);
    expect(seconds).toBeGreaterThanOrEqual(0.03);
  });
}

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
