export function join(...parts: string[]): string {
  const filtered = parts.filter((part) => part.length > 0);
  if (filtered.length === 0) return "";
  const absolute = filtered[0]!.startsWith("/");
  const joined = filtered
    .map((part, index) => {
      if (index === 0) return part.replace(/\/+$/g, "");
      return part.replace(/^\/+|\/+$/g, "");
    })
    .filter(Boolean)
    .join("/");
  return absolute ? `/${joined.replace(/^\/+/, "")}` : joined;
}

export function basename(path: string): string {
  return path.split("/").filter(Boolean).at(-1) ?? path;
}

export function stripYaml(path: string): string {
  return basename(path).replace(/\.yaml$/, "");
}

async function testPath(flag: "-e" | "-f" | "-d", path: string): Promise<boolean> {
  const code = await Bun.spawn(["test", flag, path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
  return code === 0;
}

export async function pathExists(path: string): Promise<boolean> {
  return await testPath("-e", path);
}

export async function fileExists(path: string): Promise<boolean> {
  return await testPath("-f", path);
}

export async function dirExists(path: string): Promise<boolean> {
  return await testPath("-d", path);
}

export async function readText(path: string): Promise<string> {
  return await Bun.file(path).text();
}

export async function writeText(path: string, content: string): Promise<void> {
  await Bun.write(path, content);
}

export async function deleteFile(path: string): Promise<void> {
  await Bun.spawn(["rm", "-f", path], {
    stdout: "ignore",
    stderr: "ignore",
  }).exited;
}
