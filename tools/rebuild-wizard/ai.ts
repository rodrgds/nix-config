import { HOME, OPENROUTER_MODEL } from "./config";
import { runCapture } from "./command";
import { join, pathExists, readText } from "./fs";
import { getDiffForAi } from "./git";

async function readOpenRouterApiKey(): Promise<string | null> {
  if (Bun.env.OPENROUTER_API_KEY?.trim())
    return Bun.env.OPENROUTER_API_KEY.trim();
  if (Bun.env.openrouter_api_key?.trim())
    return Bun.env.openrouter_api_key.trim();

  const uid = (
    await runCapture("id", ["-u"], { cwd: "/", check: false })
  ).trim();

  const candidates = [
    Bun.env.XDG_RUNTIME_DIR
      ? join(Bun.env.XDG_RUNTIME_DIR, "secrets/openrouter_api_key")
      : null,
    uid ? `/run/user/${uid}/secrets/openrouter_api_key` : null,
    HOME ? join(HOME, ".config/sops-nix/secrets/openrouter_api_key") : null,
  ].filter(Boolean) as string[];

  for (const candidate of candidates) {
    if (!(await pathExists(candidate))) continue;
    const value = (await readText(candidate)).trim();
    if (value) return value;
  }

  return null;
}

export async function generateCommitMessageWithOpenRouter(): Promise<
  string | null
> {
  const apiKey = await readOpenRouterApiKey();
  if (!apiKey) {
    console.error("❌ OpenRouter API key not found in env or config");
    return null;
  }

  const diff = await getDiffForAi();
  if (!diff.trim()) {
    console.error("❌ No diff available for AI commit message");
    return null;
  }

  const maxRetries = 5;
  let lastError: string | null = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(
        "https://openrouter.ai/api/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/rodrgds/nix-config",
            "X-Title": "nix-config rebuild wizard",
          },
          body: JSON.stringify({
            model: OPENROUTER_MODEL,
            messages: [
              {
                role: "system",
                content:
                  "You write concise git commit messages for a personal NixOS/nix-darwin config. Return exactly one commit subject line, no markdown, no introduction, no quotes, under 72 characters if possible.",
              },
              {
                role: "user",
                content: `Generate a commit message for this change. Do not mention encrypted secret values. Return only the commit subject line:\n\n${diff}`,
              },
            ],
            temperature: 0.2,
            max_tokens: 64,
          }),
        },
      );

      if (!response.ok) {
        const errorText = await response.text();
        lastError = `HTTP ${response.status}: ${errorText}`;
        console.error(
          `❌ Attempt ${attempt}/${maxRetries}: OpenRouter API error - ${lastError}`,
        );

        if (attempt < maxRetries) {
          const waitMs = Math.pow(2, attempt - 1) * 1000;
          console.error(`   Retrying in ${waitMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, waitMs));
        }
        continue;
      }

      const data = (await response.json()) as {
        choices?: { message?: { content?: string } }[];
        error?: { message?: string };
      };

      if (data.error) {
        lastError = data.error.message ?? "Unknown OpenRouter error";
        console.error(
          `❌ Attempt ${attempt}/${maxRetries}: OpenRouter error - ${lastError}`,
        );

        if (attempt < maxRetries) {
          const waitMs = Math.pow(2, attempt - 1) * 1000;
          console.error(`   Retrying in ${waitMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, waitMs));
        }
        continue;
      }

      const message = data.choices?.[0]?.message?.content
        ?.trim()
        .replace(/^['"]|['"]$/g, "");
      if (!message) {
        lastError = "Empty message from AI";
        console.error(`❌ Attempt ${attempt}/${maxRetries}: ${lastError}`);

        if (attempt < maxRetries) {
          const waitMs = Math.pow(2, attempt - 1) * 1000;
          console.error(`   Retrying in ${waitMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, waitMs));
        }
        continue;
      }

      console.error(
        `✓ OpenRouter generated commit message on attempt ${attempt}`,
      );
      return message;
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      lastError = msg;
      console.error(
        `❌ Attempt ${attempt}/${maxRetries}: OpenRouter request failed - ${msg}`,
      );

      if (attempt < maxRetries) {
        const waitMs = Math.pow(2, attempt - 1) * 1000;
        console.error(`   Retrying in ${waitMs}ms...`);
        await new Promise((resolve) => setTimeout(resolve, waitMs));
      }
    }
  }

  console.error(
    `❌ OpenRouter failed after ${maxRetries} attempts. Last error: ${lastError}`,
  );
  return null;
}
