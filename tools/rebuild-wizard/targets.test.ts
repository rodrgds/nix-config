import { describe, expect, test } from "bun:test";

import { TARGETS } from "./config";
import {
  allowedTargetsFor,
  buildCommand,
  deployCommand,
  needsActivation,
  parseArgs,
  postRebuildHealthCommand,
  systemdMajorChange,
} from "./targets";

const target = (name: string) => TARGETS.find((t) => t.name === name)!;

describe("arguments", () => {
  test("a plain rebuild targets this machine", () => {
    expect(parseArgs([])).toEqual({ kind: "rebuild" });
  });

  test("maps subcommands and legacy target flags", () => {
    expect(parseArgs(["update"])).toEqual({ kind: "update" });
    expect(parseArgs(["--update"])).toEqual({ kind: "update" });
    expect(parseArgs(["vps"])).toEqual({ kind: "rebuild", target: "rgo-vps" });
    expect(parseArgs(["secrets"])).toEqual({ kind: "secrets", file: undefined });
    expect(parseArgs(["secrets", "vps-secrets"])).toEqual({
      kind: "secrets",
      file: "vps-secrets",
    });
    for (const { cliFlag, name } of TARGETS) {
      expect(parseArgs([cliFlag])).toEqual({ kind: "rebuild", target: name });
    }
  });

  test("rejects unknown or combined arguments", () => {
    for (const args of [["--nope"], ["--laptop", "--vps"], ["update", "now"]]) {
      expect(() => parseArgs(args)).toThrow("Unknown arguments");
    }
  });
});

describe("targets", () => {
  test("the laptop rebuilds itself and deploys the VPS remotely", () => {
    const names = allowedTargetsFor("rgo-laptop", "darwin").map((t) => t.name);
    expect(names).toEqual(["rgo-laptop", "rgo-vps"]);
    expect(deployCommand(target("rgo-vps"), "rgo-laptop")).toEqual([
      "nix",
      ["run", ".#deploy-rs", "--", "--skip-checks", "--remote-build", ".#rgo-vps"],
    ]);
  });

  test("the desktop builds the VPS locally", () => {
    expect(deployCommand(target("rgo-vps"), "rgo-desktop")[1]).not.toContain(
      "--remote-build",
    );
  });

  test("builds go to the given out-link without root", () => {
    const [cmd, args] = buildCommand(target("rgo-laptop"), "/state/result");
    expect(cmd).toBe("nh");
    expect(args.slice(0, 7)).toEqual([
      "darwin",
      "build",
      ".",
      "-H",
      "rgo-laptop",
      "-o",
      "/state/result",
    ]);
    expect(buildCommand(target("rgo-desktop"), "/r")[1][0]).toBe("os");
  });

  test("health runs only after a local laptop rebuild", () => {
    expect(postRebuildHealthCommand(target("rgo-laptop"), "rgo-laptop")).not.toBeNull();
    expect(postRebuildHealthCommand(target("rgo-laptop"), "rgo-desktop")).toBeNull();
    expect(postRebuildHealthCommand(target("rgo-desktop"), "rgo-desktop")).toBeNull();
  });
});

describe("activation decisions", () => {
  test("skips only a live build whose last activation succeeded", () => {
    expect(needsActivation("/nix/store/a", "/nix/store/a", "/nix/store/a")).toBe(false);
    expect(needsActivation("/nix/store/b", "/nix/store/a", "/nix/store/a")).toBe(true);
    expect(needsActivation("/nix/store/a", "/nix/store/a", null)).toBe(true);
  });

  test("detects systemd major upgrades from store paths", () => {
    expect(
      systemdMajorChange("/nix/store/x-systemd-257.9", "/nix/store/y-systemd-258.1"),
    ).toEqual({ from: "257", to: "258" });
    expect(
      systemdMajorChange("/nix/store/x-systemd-258.0", "/nix/store/y-systemd-258.1"),
    ).toBeNull();
    expect(systemdMajorChange(null, "/nix/store/y-systemd-258.1")).toBeNull();
  });
});
