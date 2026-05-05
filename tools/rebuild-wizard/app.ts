import {
  BoxRenderable,
  SelectRenderable,
  SelectRenderableEvents,
  TextRenderable,
  TextareaRenderable,
  type CliRenderer,
  type ParsedKey,
  type SelectOption,
} from "@opentui/core";

import { runInteractive, visibleCommand } from "./command";
import type { ChecklistItem, CommandOptions, MenuItem } from "./types";

export class App {
  private renderer: CliRenderer;
  private screen: BoxRenderable | null = null;
  private keyHandler: ((key: ParsedKey) => void) | null = null;
  private destroyed = false;

  constructor(renderer: CliRenderer) {
    this.renderer = renderer;
    this.renderer.setBackgroundColor("transparent");

    this.renderer.keyInput.on("keypress", (key: ParsedKey) => {
      if (this.destroyed) return;
      if (key.ctrl && key.name === "c") {
        this.destroy();
        return;
      }
      this.keyHandler?.(key);
    });
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.renderer.destroy();
  }

  private reset(title: string, subtitle?: string): BoxRenderable {
    if (this.screen) {
      this.renderer.root.remove(this.screen.id);
      this.screen = null;
    }

    this.keyHandler = null;

    const screen = new BoxRenderable(this.renderer, {
      id: `screen-${Date.now()}-${Math.random()}`,
      flexDirection: "column",
      width: "100%",
      height: "100%",
      border: true,
      borderStyle: "single",
      borderColor: "#d65d0e",
      title: ` ${title} `,
      titleAlignment: "center",
      backgroundColor: "transparent",
    });

    this.renderer.root.add(screen);
    this.screen = screen;

    if (subtitle) {
      screen.add(
        new TextRenderable(this.renderer, {
          id: `subtitle-${Date.now()}-${Math.random()}`,
          height: Math.max(1, subtitle.split("\n").length),
          content: subtitle,
          fg: "#a89984",
        }),
      );
    }

    return screen;
  }

  async menu<T>(
    title: string,
    subtitle: string,
    options: MenuItem<T>[],
    opts: { allowBack?: boolean; defaultIndex?: number } = {},
  ): Promise<T | null> {
    return await new Promise<T | null>((resolve) => {
      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k to move · Enter to select${opts.allowBack ? " · q/Esc to go back" : ""} · Ctrl+C to quit`,
      );

      const selectOptions: SelectOption[] = options.map((option) => ({
        name: option.label,
        description: option.description ?? "",
        value: option.value,
      }));

      const select = new SelectRenderable(this.renderer, {
        id: `select-${Date.now()}-${Math.random()}`,
        height: "100%",
        options: selectOptions,
        showDescription: true,
        showScrollIndicator: true,
        wrapSelection: true,
        fastScrollStep: 5,
        backgroundColor: "transparent",
        focusedBackgroundColor: "transparent",
        selectedBackgroundColor: "#3c3836",
        textColor: "#ebdbb2",
        selectedTextColor: "#fe8019",
        descriptionColor: "#928374",
        selectedDescriptionColor: "#a89984",
      });

      screen.add(select);

      select.on(
        SelectRenderableEvents.ITEM_SELECTED,
        (_index: number, option: SelectOption) => {
          resolve(option.value as T);
        },
      );

      this.keyHandler = (key) => {
        if (!opts.allowBack) return;
        if (key.name === "q" || key.name === "escape") resolve(null);
      };

      select.focus();

      const defaultIndex = opts.defaultIndex ?? 0;
      for (let i = 0; i < defaultIndex; i++) {
        select.moveDown(1);
      }

      this.renderer.requestRender();
    });
  }

  async confirm(
    title: string,
    message: string,
    defaultYes = false,
  ): Promise<boolean> {
    const yesFirst = defaultYes;
    const options: MenuItem<boolean>[] = yesFirst
      ? [
          { label: "Yes", value: true },
          { label: "No", value: false },
        ]
      : [
          { label: "No", value: false },
          { label: "Yes", value: true },
        ];

    const result = await this.menu(title, message, options);
    return result ?? false;
  }

  async checklist(
    title: string,
    subtitle: string,
    items: ChecklistItem[],
    selectedValues: string[],
    opts: {
      allowBack?: boolean;
      controls?: string;
      onDefault?: () => string[];
      onAll?: () => string[];
      onNone?: () => string[];
    } = {},
  ): Promise<string[] | null> {
    return await new Promise<string[] | null>((resolve) => {
      const selected = new Set(selectedValues);
      let cursor = 0;
      let offset = 0;

      const controls =
        opts.controls ??
        "Space toggles · Enter continues · a all · n none · q/Esc back";

      const screen = this.reset(title, `${subtitle}\n${controls}`);

      const viewport = new BoxRenderable(this.renderer, {
        id: `checklist-viewport-${Date.now()}-${Math.random()}`,
        flexDirection: "column",
        height: "100%",
        width: "100%",
        backgroundColor: "transparent",
      });

      screen.add(viewport);

      const rows: TextRenderable[] = [];
      const visibleHeight = () => Math.max(6, this.renderer.terminalHeight - 6);

      const ensureRows = () => {
        const needed = visibleHeight();
        while (rows.length < needed) {
          const row = new TextRenderable(this.renderer, {
            id: `checklist-row-${Date.now()}-${Math.random()}-${rows.length}`,
            height: 1,
            content: "",
            fg: "#ebdbb2",
          });
          rows.push(row);
          viewport.add(row);
        }

        for (let i = 0; i < rows.length; i++) {
          rows[i]!.visible = i < needed;
        }
      };

      const render = () => {
        ensureRows();

        cursor = Math.max(0, Math.min(cursor, items.length - 1));
        const height = visibleHeight();

        if (cursor < offset) offset = cursor;
        if (cursor >= offset + height) offset = cursor - height + 1;
        offset = Math.max(
          0,
          Math.min(offset, Math.max(0, items.length - height)),
        );

        for (let i = 0; i < rows.length; i++) {
          const row = rows[i]!;
          if (i >= height) {
            row.visible = false;
            continue;
          }

          const index = offset + i;
          const item = items[index];

          if (!item) {
            row.visible = true;
            row.content = "";
            row.fg = "#ebdbb2";
            continue;
          }

          const marker = selected.has(item.value) ? "[x]" : "[ ]";
          const pointer = index === cursor ? ">" : " ";
          const suffix = item.description ? ` — ${item.description}` : "";
          row.visible = true;
          row.content = `${pointer} ${marker} ${item.label}${suffix}`;
          row.fg =
            index === cursor
              ? "#fe8019"
              : selected.has(item.value)
                ? "#b8bb26"
                : "#ebdbb2";
        }

        const last = rows[Math.min(height, rows.length) - 1];
        if (last && items.length > height) {
          const shownTo = Math.min(offset + height, items.length);
          last.content = `${last.content}    [${shownTo}/${items.length}]`;
        }

        this.renderer.requestRender();
      };

      const toggleCurrent = () => {
        const item = items[cursor];
        if (!item) return;
        if (selected.has(item.value)) selected.delete(item.value);
        else selected.add(item.value);
        render();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          cursor += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          cursor -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          cursor += visibleHeight();
          render();
          return;
        }

        if (key.name === "pageup") {
          cursor -= visibleHeight();
          render();
          return;
        }

        if (key.name === "g" && !key.shift && key.raw !== "G") {
          cursor = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          cursor = items.length - 1;
          render();
          return;
        }

        if (key.name === "space" || key.raw === " ") {
          toggleCurrent();
          return;
        }

        if (key.name === "a") {
          selected.clear();
          for (const value of opts.onAll?.() ??
            items.map((item) => item.value)) {
            selected.add(value);
          }
          render();
          return;
        }

        if (key.name === "d" && opts.onDefault) {
          selected.clear();
          for (const value of opts.onDefault()) selected.add(value);
          render();
          return;
        }

        if (key.name === "n") {
          selected.clear();
          for (const value of opts.onNone?.() ?? []) selected.add(value);
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve([...selected]);
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve(null);
        }
      };

      render();
    });
  }

  async input(
    title: string,
    subtitle: string,
    initialValue = "",
  ): Promise<string | null> {
    return await new Promise<string | null>((resolve) => {
      const screen = this.reset(
        title,
        `${subtitle}\nEnter accepts · Esc cancels · Ctrl+C quits`,
      );

      const box = new BoxRenderable(this.renderer, {
        id: `input-box-${Date.now()}-${Math.random()}`,
        border: true,
        borderStyle: "single",
        borderColor: "#928374",
        height: 5,
        width: "100%",
        backgroundColor: "transparent",
      });

      const input = new TextareaRenderable(this.renderer, {
        id: `input-${Date.now()}-${Math.random()}`,
        width: "100%",
        height: 1,
        placeholder: "Commit message",
        placeholderColor: "#928374",
        backgroundColor: "transparent",
        focusedBackgroundColor: "transparent",
        textColor: "#ebdbb2",
        focusedTextColor: "#ebdbb2",
        cursorColor: "#fe8019",
        wrapMode: "none",
        showCursor: true,
      });

      box.add(input);
      screen.add(box);
      input.editBuffer.setText(initialValue);
      input.focus();

      this.keyHandler = (key) => {
        const preventDefault = (
          key as ParsedKey & { preventDefault?: () => void }
        ).preventDefault;

        if (key.name === "return" || key.name === "linefeed") {
          preventDefault?.call(key);
          resolve(input.editBuffer.getText().trim());
        }

        if (key.name === "escape") {
          preventDefault?.call(key);
          resolve(null);
        }
      };

      this.renderer.requestRender();
    });
  }

  async scrollText(
    title: string,
    subtitle: string,
    content: string,
    opts: { allowBack?: boolean; enterLabel?: string } = {},
  ): Promise<"enter" | "back"> {
    return await new Promise<"enter" | "back">((resolve) => {
      const lines = content.split("\n");
      let offset = 0;

      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k scroll · PgUp/PgDn fast · ${opts.enterLabel ?? "Enter continue"}${opts.allowBack ? " · q/Esc back" : ""}`,
      );

      const body = new TextRenderable(this.renderer, {
        id: `scroll-${Date.now()}-${Math.random()}`,
        height: "100%",
        content: "",
        fg: "#ebdbb2",
      });

      screen.add(body);

      const render = () => {
        const height = Math.max(8, this.renderer.terminalHeight - 7);
        const maxOffset = Math.max(0, lines.length - height);
        offset = Math.max(0, Math.min(offset, maxOffset));

        const visible = lines.slice(offset, offset + height).join("\n");
        const counter = `\n\n[${Math.min(offset + height, lines.length)}/${lines.length} lines]`;
        body.content = `${visible}${counter}`;
        this.renderer.requestRender();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          offset += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          offset -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          offset += Math.max(8, this.renderer.terminalHeight - 8);
          render();
          return;
        }

        if (key.name === "pageup") {
          offset -= Math.max(8, this.renderer.terminalHeight - 8);
          render();
          return;
        }

        if (key.name === "g" && !key.shift) {
          offset = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          offset = lines.length;
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve("enter");
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve("back");
        }
      };

      render();
    });
  }

  async coloredDiff(
    title: string,
    subtitle: string,
    status: string,
    stat: string,
    diff: string,
    opts: { allowBack?: boolean; enterLabel?: string } = {},
  ): Promise<"enter" | "back"> {
    return await new Promise<"enter" | "back">((resolve) => {
      const lines = [
        "GIT STATUS",
        status.trim() || "No uncommitted changes.",
        "",
        "DIFF STAT",
        stat.trim() ||
          "No tracked diff stat. You may only have untracked files.",
        "",
        "FULL DIFF",
        ...(diff.trim() ? diff.split("\n") : ["No diff."]),
      ];

      let offset = 0;

      const screen = this.reset(
        title,
        `${subtitle}\n↑/↓ or j/k scroll · PgUp/PgDn fast · g top · G bottom · ${opts.enterLabel ?? "Enter continue"}${opts.allowBack ? " · q/Esc back" : ""}`,
      );

      const viewport = new BoxRenderable(this.renderer, {
        id: `diff-viewport-${Date.now()}-${Math.random()}`,
        flexDirection: "column",
        height: "100%",
        width: "100%",
        backgroundColor: "transparent",
      });

      screen.add(viewport);

      const lineRenderables: TextRenderable[] = [];
      const visibleHeight = () => Math.max(8, this.renderer.terminalHeight - 6);

      const colorForLine = (line: string): string => {
        if (line.startsWith("+") && !line.startsWith("+++")) return "#b8bb26";
        if (line.startsWith("-") && !line.startsWith("---")) return "#fb4934";
        if (line.startsWith("@@")) return "#83a598";
        if (line.startsWith("diff --git")) return "#fe8019";
        if (line.startsWith("index ")) return "#d3869b";
        if (line.startsWith("+++ ") || line.startsWith("--- "))
          return "#fabd2f";
        if (
          line === "GIT STATUS" ||
          line === "DIFF STAT" ||
          line === "FULL DIFF"
        )
          return "#fe8019";
        if (/^\s*[MADRCU?]{1,2}\s+/.test(line)) return "#d3869b";
        return "#ebdbb2";
      };

      const trimLine = (line: string): string => {
        const width = Math.max(20, this.renderer.terminalWidth - 4);
        if (line.length <= width) return line;
        return `${line.slice(0, width - 1)}…`;
      };

      const ensureLineRenderables = () => {
        const needed = visibleHeight();
        while (lineRenderables.length < needed) {
          const line = new TextRenderable(this.renderer, {
            id: `diff-line-${Date.now()}-${Math.random()}-${lineRenderables.length}`,
            height: 1,
            content: "",
            fg: "#ebdbb2",
          });
          lineRenderables.push(line);
          viewport.add(line);
        }

        for (let i = 0; i < lineRenderables.length; i++) {
          lineRenderables[i]!.visible = i < needed;
        }
      };

      const render = () => {
        ensureLineRenderables();

        const height = visibleHeight();
        const maxOffset = Math.max(0, lines.length - height);
        offset = Math.max(0, Math.min(offset, maxOffset));

        for (let i = 0; i < lineRenderables.length; i++) {
          const renderable = lineRenderables[i]!;
          if (i >= height) {
            renderable.visible = false;
            continue;
          }

          const line = lines[offset + i] ?? "";
          renderable.visible = true;
          renderable.content = trimLine(line);
          renderable.fg = colorForLine(line);
        }

        const last =
          lineRenderables[Math.min(height, lineRenderables.length) - 1];
        if (last) {
          const end = Math.min(offset + height, lines.length);
          last.content = `${trimLine(lines[offset + height - 1] ?? "")}    [${end}/${lines.length}]`;
          last.fg = colorForLine(lines[offset + height - 1] ?? "");
        }

        this.renderer.requestRender();
      };

      this.keyHandler = (key) => {
        if (key.name === "down" || key.name === "j") {
          offset += 1;
          render();
          return;
        }

        if (key.name === "up" || key.name === "k") {
          offset -= 1;
          render();
          return;
        }

        if (key.name === "pagedown") {
          offset += Math.max(8, visibleHeight() - 1);
          render();
          return;
        }

        if (key.name === "pageup") {
          offset -= Math.max(8, visibleHeight() - 1);
          render();
          return;
        }

        if (key.name === "g" && !key.shift && key.raw !== "G") {
          offset = 0;
          render();
          return;
        }

        if ((key.name === "g" && key.shift) || key.raw === "G") {
          offset = lines.length;
          render();
          return;
        }

        if (key.name === "return" || key.name === "linefeed") {
          resolve("enter");
          return;
        }

        if (opts.allowBack && (key.name === "q" || key.name === "escape")) {
          resolve("back");
        }
      };

      render();
    });
  }

  async logScreen(
    title: string,
    subtitle: string,
    runner: (append: (line: string) => void) => Promise<void>,
  ): Promise<boolean> {
    const screen = this.reset(title, subtitle);
    const body = new TextRenderable(this.renderer, {
      id: `log-${Date.now()}-${Math.random()}`,
      height: "100%",
      content: "",
      fg: "#ebdbb2",
    });

    screen.add(body);

    const lines: string[] = [];
    let done = false;
    let success = false;

    const render = () => {
      const height = Math.max(8, this.renderer.terminalHeight - 6);
      const visible = lines.slice(-height).join("\n");
      const footer = done
        ? success
          ? "\n\nDone. Press Enter to continue."
          : "\n\nFailed. Press Enter to continue."
        : "\n\nRunning…";
      body.content = `${visible}${footer}`;
      this.renderer.requestRender();
    };

    const append = (line: string) => {
      for (const part of line.replace(/\r/g, "").split("\n")) {
        lines.push(part);
      }
      render();
    };

    this.keyHandler = (key) => {
      if (!done) return;
      if (key.name === "return" || key.name === "linefeed") {
        this.keyHandler = null;
      }
    };

    render();

    try {
      await runner(append);
      success = true;
    } catch (error) {
      success = false;
      append("");
      append(error instanceof Error ? error.message : String(error));
    } finally {
      done = true;
      render();
    }

    await new Promise<void>((resolve) => {
      this.keyHandler = (key) => {
        if (key.name === "return" || key.name === "linefeed") resolve();
      };
    });

    return success;
  }

  async externalCommandScreen(
    title: string,
    subtitle: string,
    cmd: string,
    args: string[],
    options: CommandOptions = {},
  ): Promise<boolean> {
    this.reset(
      title,
      [
        subtitle,
        "",
        "The next command needs the real terminal.",
        "OpenTUI will temporarily leave the alternate screen.",
        "When the command finishes, press Enter to return to the wizard.",
      ].join("\n"),
    );

    this.renderer.requestRender();
    await sleep(150);

    const rendererAny = this.renderer as unknown as {
      stop?: () => void;
      start?: () => void;
    };

    try {
      rendererAny.stop?.();
    } catch {
      // Older OpenTUI versions may not expose stop().
    }

    try {
      process.stdin.setRawMode?.(false);
    } catch {
      // Ignore if stdin is not a TTY.
    }

    process.stdout.write("\u001b[0m\u001b[?25h\u001b[?1049l");
    process.stdout.write("\n");
    process.stdout.write(`$ ${visibleCommand(cmd, args)}\n\n`);

    let success = false;

    try {
      // OpenTUI keeps stdin in flowing mode for key handling. If the parent
      // process continues reading while a child command inherits the same TTY,
      // password prompts from sudo/nh/sops can appear to ignore typing because
      // this process wins the race and consumes the bytes first.
      process.stdin.pause();
      await runInteractive(cmd, args, options);
      success = true;
    } catch (error) {
      success = false;
      process.stdout.write("\n");
      process.stdout.write(
        error instanceof Error ? error.message : String(error),
      );
      process.stdout.write("\n");
    }

    try {
      process.stdin.setRawMode?.(false);
    } catch {
      // Ignore if stdin is not a TTY.
    }

    process.stdout.write("\nPress Enter to return to the wizard...");
    await new Promise<void>((resolve) => {
      const onData = () => {
        process.stdin.off("data", onData);
        process.stdin.pause();
        resolve();
      };

      process.stdin.once("data", onData);
      process.stdin.resume();
    });

    process.stdout.write("\u001b[?1049h\u001b[2J\u001b[H\u001b[?25l");

    try {
      process.stdin.setRawMode?.(true);
    } catch {
      // Ignore if stdin is not a TTY.
    }

    try {
      rendererAny.start?.();
    } catch {
      // If OpenTUI has no resumable start(), the next render still often works.
    }

    process.stdin.resume();

    this.reset(
      success ? "Command finished" : "Command failed",
      success
        ? "The external command completed successfully."
        : "The external command failed. See the terminal output above.",
    );

    await new Promise<void>((resolve) => {
      this.keyHandler = (key) => {
        if (key.name === "return" || key.name === "linefeed") resolve();
      };
    });

    return success;
  }
}


function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
