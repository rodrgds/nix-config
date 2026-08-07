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

  test("builds rgo-vps on the VPS from the Darwin laptop", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-vps");
    expect(target).toBeDefined();

    const [command, args] = rebuildCommand(target!, "rgo-laptop");

    expect(command).toBe("nix");
    expect(args).toEqual([
      "run",
      "path:.#deploy-rs",
      "--",
      "--skip-checks",
      "--remote-build",
      "path:.#rgo-vps",
      "--",
      "--impure",
      "--option",
      "min-free",
      String(8 * 1024 * 1024 * 1024),
      "--option",
      "max-free",
      String(16 * 1024 * 1024 * 1024),
      "--option",
      "substituters",
      "https://cache.nixos.org",
    ]);
  });

  test("builds rgo-vps locally from the Linux desktop", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-vps");
    expect(target).toBeDefined();

    const [command, args] = rebuildCommand(target!, "rgo-desktop");

    expect(command).toBe("nix");
    expect(args).not.toContain("--remote-build");
    expect(args).toContain("path:.#rgo-vps");
  });
});
