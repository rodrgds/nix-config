import { describe, expect, test } from "bun:test";

import { TARGETS } from "./config";
import { allowedTargetsFor, rebuildCommand } from "./targets";

describe("remote VPS rebuilds", () => {
  test("offers rgo-vps from the Darwin laptop", async () => {
    const targets = await allowedTargetsFor("rgo-laptop", "darwin");

    expect(targets.map((target) => target.name)).toEqual([
      "rgo-laptop",
      "rgo-vps",
    ]);
  });

  test("builds and activates rgo-vps remotely with nh", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-vps");
    expect(target).toBeDefined();

    const [command, args] = rebuildCommand(target!);

    expect(command).toBe("nh");
    for (const arg of [
      "os",
      "switch",
      "path:.",
      "-H",
      "rgo-vps",
      "--target-host",
      "rgo@rgo-vps",
      "--build-host",
      "--elevation-strategy",
      "passwordless",
      "--show-activation-logs",
      "--impure",
    ]) {
      expect(args).toContain(arg);
    }
  });
});
