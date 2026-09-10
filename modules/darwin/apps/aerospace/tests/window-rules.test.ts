import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

// Exercise AeroSpace's documented first-match rule processing against the
// configured callbacks. No desktop changes are needed to catch shadowed rules.
const source = readFileSync(new URL("../default.nix", import.meta.url), "utf8");
const start = source.indexOf("[[on-window-detected]]");
const end = source.indexOf("          '';", start);
const rules = Bun.TOML.parse(source.slice(start, end))["on-window-detected"] as Array<{
  if: { "app-id"?: string; "window-title-regex-substring"?: string };
  run: string | string[];
  "check-further-callbacks"?: boolean;
}>;
function commands(app: string, title: string) {
  const result: string[] = [];
  for (const rule of rules) {
    if (rule.if["app-id"] && rule.if["app-id"] !== app) continue;
    const pattern = rule.if["window-title-regex-substring"];
    if (pattern && !new RegExp(pattern).test(title)) continue;
    result.push(...[rule.run].flat());
    if (!rule["check-further-callbacks"]) break;
  }
  return result;
}
test("Finder info windows float and keep their workspace assignment", () => {
  expect(commands("com.apple.finder", "file Info")).toEqual([
    "layout floating", "move-node-to-workspace 3",
  ]);
});
test("browser PiP floats and keeps its workspace assignment", () => {
  for (const app of ["com.brave.Browser", "com.google.Chrome", "com.microsoft.edgemac"]) {
    expect(commands(app, "Picture-in-Picture")).toEqual([
      "layout floating", "move-node-to-workspace 2",
    ]);
  }
});
test("ordinary Finder, browser and music windows retain their assignments", () => {
  expect(commands("com.apple.finder", "Home")).toEqual(["move-node-to-workspace 3"]);
  expect(commands("com.brave.Browser", "New Tab")).toEqual(["move-node-to-workspace 2"]);
  expect(commands("com.apple.Music", "Music")).toEqual(["move-node-to-workspace 10"]);
  expect(commands("unknown", "Document")).toEqual([]);
});
