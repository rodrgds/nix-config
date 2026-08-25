import { describe, expect, test } from "bun:test";

import { TARGETS } from "./config";
import {
  allowedTargetsFor,
  directTargetHelp,
  directTargetFromArgs,
  directTargetUsage,
  postRebuildHealthCommand,
  rebuildCommand,
} from "./targets";

describe("direct rebuild flags", () => {
  test("keeps the TUI for a plain rebuild", () => {
    expect(directTargetFromArgs([])).toBeNull();
  });

  test("maps every configured target flag", () => {
    for (const target of TARGETS) {
      expect(directTargetFromArgs([target.cliFlag])).toBe(target.name);
    }
  });

  test("rejects unknown or combined arguments", () => {
    expect(() => directTargetFromArgs(["--unknown"])).toThrow(
      directTargetUsage(),
    );
    expect(() => directTargetFromArgs(["--desktop", "--laptop"])).toThrow(
      directTargetUsage(),
    );
  });

  test("assigns one unique CLI flag to every target", () => {
    const flags = TARGETS.map(({ cliFlag }) => cliFlag);
    expect(new Set(flags).size).toBe(TARGETS.length);
  });

  test("generates help from the configured targets", () => {
    const help = directTargetHelp();
    for (const target of TARGETS) {
      expect(help).toContain(target.cliFlag);
      expect(help).toContain(target.name);
      expect(help).toContain(target.description);
    }
  });
});

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

describe("local rebuild visibility", () => {
  test("shows nix-darwin activation logs", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-laptop");
    expect(target).toBeDefined();

    const [, args] = rebuildCommand(target!, "rgo-laptop");
    expect(args).toContain("--show-activation-logs");
  });

  test("checks laptop health after a local Darwin rebuild", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-laptop");
    expect(target).toBeDefined();

    expect(postRebuildHealthCommand(target!, "rgo-laptop")).toEqual([
      "/run/current-system/sw/bin/rgo-laptop-health",
      [],
    ]);
  });

  test("does not run laptop health for another host", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-laptop");
    expect(target).toBeDefined();

    expect(postRebuildHealthCommand(target!, "rgo-desktop")).toBeNull();
  });

  test("shows NixOS activation logs", () => {
    const target = TARGETS.find(({ name }) => name === "rgo-desktop");
    expect(target).toBeDefined();

    const [, args] = rebuildCommand(target!, "rgo-desktop");
    expect(args).toContain("--show-activation-logs");
  });
});
