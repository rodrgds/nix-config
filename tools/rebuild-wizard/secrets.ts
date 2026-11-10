import { existsSync, lstatSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { AGE_KEY_FILE, REPO_DIR, SECRETS_DIR } from "./config";
import { commandExists, runCapture, runInteractive } from "./command";

export async function listPlainSecretFiles(): Promise<string[]> {
  try {
    try {
      lstatSync(SECRETS_DIR);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
      throw error;
    }
    if (!statSync(SECRETS_DIR).isDirectory()) {
      throw new Error("Secrets path is not a directory.");
    }
    // Plaintext must never reach a build or commit, even if .gitignore
    // changes. Match every extension and fail closed on unreadable
    // directories, broken roots, or symlink traversal errors.
    const output = await runCapture(
      "find",
      ["-L", SECRETS_DIR, "-name", "*_plain*", "-print0"],
      { cwd: REPO_DIR },
    );
    return output.split("\0").filter(Boolean).sort();
  } catch (error) {
    throw new Error(
      `Cannot scan plaintext secrets in ${SECRETS_DIR}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

export async function assertNoPlainSecrets(action: string): Promise<void> {
  const files = await listPlainSecretFiles();
  if (files.length === 0) return;
  throw new Error(
    [
      `Refusing to ${action} while plaintext secret paths exist:`,
      ...files.map((file) => `  - ${JSON.stringify(file)}`),
      "",
      "A mis-ignored plaintext file would be copied into the world-readable Nix store.",
      "Encrypt or remove these paths first (`rebuild secrets` edits secrets in place).",
    ].join("\n"),
  );
}

// Git flakes ignore untracked files, which would silently drop new modules
// from import-tree. Intent-to-add makes them visible without staging content.
export async function exposeNewFilesToFlake(): Promise<void> {
  await runCapture("git", ["add", "--intent-to-add", "--ignore-removal", "."], {
    cwd: REPO_DIR,
    check: false,
  });
}

// Edits an encrypted file in place; sops keeps plaintext out of the checkout.
export async function editSecrets(name = "secrets"): Promise<number> {
  const file = join(SECRETS_DIR, `${name.replace(/\.ya?ml$/, "")}.yaml`);
  if (!existsSync(file)) {
    const available = readdirSync(SECRETS_DIR)
      .filter((entry) => /\.ya?ml$/.test(entry) && !entry.startsWith("."))
      .map((entry) => entry.replace(/\.ya?ml$/, ""));
    throw new Error(
      `No secrets file ${file}.\nAvailable: ${available.join(", ")}`,
    );
  }
  const sops: [string, string[]] = (await commandExists("sops"))
    ? ["sops", []]
    : ["nix", ["shell", "nixpkgs#sops", "-c", "sops"]];
  const code = await runInteractive(
    sops[0],
    [...sops[1], "--config", join(SECRETS_DIR, ".sops.yaml"), "edit", file],
    {
      check: false,
      env: { SOPS_AGE_KEY_FILE: AGE_KEY_FILE },
      phase: "sops edit",
    },
  );
  // sops exits 200 when the file was left unchanged.
  if (code === 200) return 0;
  if (code === 0) {
    console.log(
      "\nNew keys need a consumer: declare `sops.secrets.<key>` in the module that uses it, then run `rebuild`.",
    );
  }
  return code;
}
