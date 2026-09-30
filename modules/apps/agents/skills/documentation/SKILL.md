---
name: documentation
description: Write, simplify, or reorganize product and developer documentation. Use for guides, tutorials, setup instructions, reference pages, navigation, and instructional images. Ground content in the product and give each page a clear reader purpose.
---

# Documentation

Help the reader finish a task or find an answer. Use [source patterns](references/source-patterns.md) when choosing a structure or reviewing an unfamiliar documentation set.

## Decide what belongs

Before editing, name the reader and the task or question each page answers. Check the current product, code, or authoritative source for the behavior being described.

- A tutorial takes a new reader to one visible result. Choose one working path and show how to verify it.
- A task guide gives the steps needed to finish a specific job. Keep the whole job on one page. Put alternate tools or clients under headings or tabs when the task is the same.
- Reference organizes exact options, limits, commands, or API contracts for lookup. Generate it from the owner where possible.
- Explanation answers a concrete why question. Link it from the task that needs it.

Merge pages that repeat an answer or divide one task into fragments. Split only when readers have independent goals. Remove pages without a useful distinct purpose, preserving any unique facts in their owner. Keep landing pages short and use them to choose a task.

Keep shared setup, permissions, credentials, and limits in one owner page. Link to them where needed. Keep customer instructions separate from operator setup and engineering contracts.

## Write the page

Lead with the action or answer. For a task, give necessary prerequisites, ordered steps, and an observable completion check. Use exact UI labels and copyable commands. Explain placeholders and required values. Put a caveat beside the step it changes.

Use headings that name actions or questions. Replace dense paragraphs with steps, short examples, or comparison tables only when those formats make the content easier to use. Keep optional context behind links. Apply `unslop` after structural editing. Preserve facts and complete sentences while cutting repetition, filler, and internal terminology the reader does not need.

## Choose images

Keep an image only if it helps locate a hard-to-find control, understand a relationship, or check a result. Inspect the pixels. Empty canvases, loading states, generic dashboards, and screenshots of a button already named in the text do not earn space.

Place a useful image beside its step, crop to the relevant area, and explain what the reader should notice. Keep instructions usable without the image. Verify small-screen readability, alt text, appearance, and attribution. Remove outdated or misleading images rather than inventing a replacement.

## Finish

Review every changed page for purpose, factual accuracy, duplicated facts, prose, and image value. Check the sidebar and search path a reader would use. For removed or moved pages, update incoming links and preserve useful old URLs with redirects to the relevant surviving answer.

Run the project's documentation build and link checks. Inspect the rendered result at desktop and phone widths, including retained images and code. Verify keyboard navigation, light/dark appearance, search, downloads, and redirects when those surfaces changed. Report actual improvements and any verification gap, not just a word-count change.
