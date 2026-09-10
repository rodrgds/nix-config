---
name: devenv
description: "Configure or troubleshoot devenv.sh environments and their Nix files. Routine commands in an established environment follow the repository instructions."
---

# devenv

For ordinary commands in an existing environment, follow the repository's commands. For configuration or version-sensitive troubleshooting, inspect the relevant Nix files and `devenv version`; use documentation for the pinned version.

Read only the reference needed for the task:

- Configuration, inputs, and Nix syntax: [config-reference.md](references/config-reference.md).
- Language runtimes and package managers: [languages.md](references/languages.md).
- Services, processes, and task dependencies: [services-processes.md](references/services-processes.md).
- New environment setup, CLI operations, activation, and build failures: [cli-operations.md](references/cli-operations.md).
- Uncertain option names or version compatibility: [official-sources.md](references/official-sources.md).

## Constraints

- Prefer language and service modules for their integration; use packages for standalone tools.
- Preserve input pins unless an update is requested. `devenv update` changes the lockfile.
- Keep heavy setup in cacheable tasks; shell entry should stay fast.
- Declared services still need to be started. Entering a shell is not proof they are running.
- Keep secrets out of Nix strings and the Nix store; use the project's runtime secret mechanism.
- After configuration changes, verify evaluation and the affected command or service. An evaluation alone does not prove runtime behavior.
