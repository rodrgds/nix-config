# Source patterns

These observations informed the skill on 2026-09-30. Borrow the useful structure, not every sentence or the size of each project's navigation.

- [Social SDK overview](https://github.com/opencoredev/social-sdk/blob/main/apps/docs/docs/index.mdx) gives readers short routes to a first example, integration choice, guides, and reference. Its [mock quickstart](https://github.com/opencoredev/social-sdk/blob/main/apps/docs/docs/getting-started/mock-quickstart.mdx) uses a runnable example, expected output, and a failure exercise without screenshots. [Navigation source](https://github.com/opencoredev/social-sdk/blob/main/apps/docs/docs/meta.ts) makes the order explicit.
- [Docker's writing guide](https://github.com/docker/docs/blob/main/STYLE.md) separates tutorials, task guides, reference, and explanation. Complete a task on one page instead of dividing overview, configuration, and deployment. Its [first-image guide](https://github.com/docker/docs/blob/main/content/get-started/introduction/build-and-push-first-image.md) pairs commands with checks; screenshots identify particular UI actions.
- [Astro installation](https://github.com/withastro/docs/blob/main/src/content/docs/en/install-and-setup.mdx) puts the shortest setup route first, keeps package-manager choices together, and links detailed CLI options elsewhere.
- [The Rust book's first program](https://github.com/rust-lang/book/blob/main/src/ch01-02-hello-world.md) shows code and expected output before explaining syntax. This is useful for first-use tutorials; its longer teaching prose is less suitable for routine product help.
- [Diataxis task guides](https://diataxis.fr/how-to-guides/) center a real reader goal. [Reference guidance](https://diataxis.fr/reference/) favors precise, consistent descriptions and links to separate instructions or explanations.

For a product-help rewrite, prefer complete tasks, a short route picker, one owner for shared facts, visible completion checks, and images with a specific instructional job. Treat long conceptual introductions, exhaustive sidebars, and repeated summaries as context-dependent choices rather than defaults.
