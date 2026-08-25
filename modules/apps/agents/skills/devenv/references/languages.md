# Language modules

Verified against devenv 2.1.x. Full per-language options: `https://devenv.sh/languages/` and the option reference.

## Principles

- Enable a toolchain with `languages.<lang>.enable = true;` — this wires PATH, env vars, and integration that a raw `pkgs.<tool>` in `packages` does not.
- Most sub-features (venv, a specific package manager, auto-install) default to **off** and each needs its own `enable = true`.
- Pin versions when reproducibility across machines matters; otherwise the input's nixpkgs decides the version.
- For native build dependencies (headers/shared libs needed to compile packages like Pillow, grpcio, native node modules), add them to `packages` or the language's `libraries` option.

## Python

```nix
languages.python = {
  enable = true;
  version = "3.12";              # "3.12" or exact "3.12.3"

  venv.enable = true;            # create/activate a virtualenv
  venv.requirements = ./requirements.txt;   # path or inline string; installed into the venv

  uv.enable = true;              # uv (fast, modern) — recommended
  uv.sync.enable = true;         # run `uv sync` from pyproject.toml/uv.lock on activation

  # poetry.enable = true;
  # poetry.install.enable = true;

  libraries = [ pkgs.zlib pkgs.stdenv.cc.cc.lib ];   # native libs for wheels that link C
};
```

Pick **one** dependency path: `venv` + `requirements`, or `uv` (+ `uv.sync`), or `poetry`. Mixing them causes confusion. `uv` is the current default recommendation for new projects.

## JavaScript / TypeScript

Each package manager is independent and off by default; `install.enable` auto-installs deps on activation.

```nix
languages.javascript = {
  enable = true;
  package = pkgs.nodejs_22;      # default is a slim node; set explicitly to pin major
  pnpm.enable = true;
  pnpm.install.enable = true;    # runs `pnpm install` on activation
  # npm.enable / yarn.enable / bun.enable similarly
  # corepack.enable = true;      # provides npm/pnpm/yarn shims per package.json
};
languages.typescript.enable = true;   # adds tsc; separate from javascript
```

`languages.deno.enable` and `languages.bun.enable` exist as standalone runtimes too.

## Rust

```nix
languages.rust = {
  enable = true;
  channel = "stable";            # nixpkgs | stable | beta | nightly
  components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ];
  targets = [ "wasm32-unknown-unknown" ];
  mold.enable = true;            # faster linker on Linux
};
packages = [ pkgs.cargo-watch pkgs.openssl pkgs.pkg-config ];  # common crate build deps
```

`stable`/`beta`/`nightly` use the Fenix/rust-overlay toolchains (precise channel control); `nixpkgs` uses whatever rustc your nixpkgs ships.

## Go

```nix
languages.go = {
  enable = true;
  package = pkgs.go_1_23;        # pin the toolchain
};
```

## Other languages

The same pattern holds for `languages.elixir`, `languages.erlang`, `languages.ruby`, `languages.php`, `languages.java`, `languages.dotnet`, `languages.c`, `languages.cplusplus`, `languages.zig`, `languages.haskell`, `languages.ocaml`, `languages.nix`, and many more. Each has `enable`, usually a `package`/`version`, and toolchain-specific options. When you need the exact options for one, check `https://devenv.sh/languages/<lang>/` or run `devenv search languages.<lang>`.

## Choosing a version that exists

`languages.<lang>.version` only accepts versions the module knows how to resolve; a typo or unavailable version fails at evaluation. If pinning a precise version is fragile, pin via `package = pkgs.<specific>` instead (e.g. `pkgs.nodejs_22`, `pkgs.go_1_23`, `pkgs.python311`), which references a concrete nixpkgs attribute. Use `devenv search <name>` to confirm the attribute exists.
