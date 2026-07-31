---
name: devenv
description: Use when working with devenv, a tool for declarative developer environments using Nix.
---

# devenv

devenv is a powerful tool for creating fast, declarative, reproducible, and composable developer environments using Nix. It provides a simple configuration interface through `devenv.nix` and `devenv.yaml` files, enabling teams to define consistent development setups that work across all platforms. The tool handles package management, language toolchains, services, processes, tasks, scripts, git hooks, and container generation through a unified Nix-based configuration.

At its core, devenv abstracts away Nix complexity while preserving its benefits: reproducibility, isolation, and cross-platform compatibility. Developers define their environment declaratively - specifying languages, packages, services, and processes - and devenv handles the rest. The tool supports over 50 programming languages, dozens of services (PostgreSQL, Redis, MySQL, etc.), process supervision with health checks, task automation with dependencies, and OCI container generation for deployment.

## Initialize a New Project

Create a new devenv project with scaffold files for configuration.

```bash
# Initialize devenv in current directory
devenv init
# Output:
# Creating .envrc
# Creating devenv.nix
# Creating devenv.yaml
# Creating .gitignore

# Enter the development shell
devenv shell

# Run tests to verify environment
devenv test
```

## Basic Configuration (devenv.nix)

Define environment variables, packages, and shell initialization in `devenv.nix`.

```nix
# devenv.nix
{ pkgs, lib, config, ... }:

{
  # Environment variables
  env.GREET = "devenv";
  env.DATABASE_URL = "postgres://localhost/mydb";

  # Packages available in shell
  packages = [
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.ripgrep
  ];

  # Shell initialization
  enterShell = ''
    echo "Welcome to the development environment!"
    echo "Git version: $(git --version)"
  '';

  # Test commands for CI
  enterTest = ''
    echo "Running tests..."
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
```

## Language Support - Python

Enable Python with virtual environment and pip dependencies.

```nix
# devenv.nix
{ pkgs, ... }:

{
  languages.python = {
    enable = true;
    version = "3.11.3";

    # Automatic venv with requirements
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  # Alternative: Poetry support
  # languages.python = {
  #   enable = true;
  #   poetry.enable = true;
  #   poetry.install.enable = true;
  # };
}
```

## Language Support - Rust

Configure Rust development with toolchain management and git hooks.

```nix
# devenv.nix
{ pkgs, lib, config, ... }:

{
  languages.rust = {
    enable = true;
    channel = "stable";  # or "nightly", "beta", "nixpkgs"
    version = "1.81.0";  # or "latest"

    # Additional components
    components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ];

    # Cross-compilation targets
    targets = [ "wasm32-unknown-unknown" "aarch64-unknown-linux-gnu" ];
  };

  # Git hooks for Rust
  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
  };
}
```

## Language Support - JavaScript/Node.js

Set up JavaScript/TypeScript development with npm, yarn, or bun.

```nix
# devenv.nix
{ pkgs, ... }:

{
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_20;
    npm.enable = true;
    npm.install.enable = true;  # Auto-install on shell entry
  };

  # Alternative: Yarn
  # languages.javascript = {
  #   enable = true;
  #   yarn.enable = true;
  #   yarn.install.enable = true;
  # };

  # Alternative: Bun
  # languages.javascript = {
  #   enable = true;
  #   bun.enable = true;
  # };
}
```

## Services - PostgreSQL

Enable PostgreSQL with extensions, initial databases, and scripts.

```nix
# devenv.nix
{ pkgs, ... }:

{
  packages = [ pkgs.coreutils ];

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_15;

    # Extensions
    extensions = extensions: [
      extensions.postgis
      extensions.pg_trgm
    ];

    # Initial setup
    initialDatabases = [
      { name = "mydb"; }
      { name = "testdb"; }
    ];

    initialScript = ''
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS pg_trgm;
    '';

    # Configuration
    settings = {
      max_connections = 100;
      shared_buffers = "256MB";
    };
  };
}
```

## Services - Redis

Configure Redis for caching and session management.

```nix
# devenv.nix
{ pkgs, ... }:

{
  services.redis = {
    enable = true;
    port = 6379;

    # Configuration options
    settings = {
      maxmemory = "256mb";
      maxmemory-policy = "allkeys-lru";
    };
  };

  # Access Redis in scripts
  scripts.redis-ping.exec = ''
    redis-cli ping
  '';
}
```

## Processes

Define and manage background processes with supervision, health checks, and dependencies.

```nix
# devenv.nix
{ pkgs, config, ... }:

{
  processes = {
    # Simple process
    server = {
      exec = "${pkgs.python3}/bin/python -m http.server ${toString config.processes.server.ports.http.value}";
      ports.http.allocate = 8080;  # Auto-allocate port
      cwd = "./public";

      # Health check
      ready.http.get = {
        port = config.processes.server.ports.http.value;
        path = "/";
      };

      # Restart policy
      restart.on = "on_failure";  # or "always", "never"
      restart.max = 5;
    };

    # Process with dependency
    worker = {
      exec = ''
        echo "Server is ready, starting worker"
        exec sleep infinity
      '';
      after = [ "devenv:processes:server" ];  # Wait for server to be ready
    };

    # File watching
    backend = {
      exec = "cargo run";
      watch = {
        paths = [ ./src ];
        extensions = [ "rs" "toml" ];
        ignore = [ "target" "*.log" ];
      };
    };
  };
}
```

```bash
# Start all processes
devenv up

# Start with strict port allocation (fail if port in use)
devenv up --strict-ports
```

## Tasks

Create tasks with dependencies, caching, and parallel execution.

```nix
# devenv.nix
{ pkgs, lib, config, ... }:

{
  tasks = {
    # Basic task
    "myapp:hello" = {
      exec = ''echo "Hello, world!"'';
    };

    # Task with shell entry hook
    "myapp:setup" = {
      exec = "npm install";
      before = [ "devenv:enterShell" ];  # Run on shell entry
    };

    # Task with status check (skip if already done)
    "myapp:migrations" = {
      exec = "db-migrate";
      status = "db-needs-migrations";
    };

    # Task that only runs when files change
    "myapp:build" = {
      exec = "npm run build";
      execIfModified = [
        "src/**/*.ts"
        "package.json"
      ];
      cwd = "./frontend";
    };

    # Task with inputs/outputs
    "myapp:process" = {
      exec = ''
        echo $DEVENV_TASK_INPUT > input.json
        echo '{"result": "success"}' > $DEVENV_TASK_OUTPUT_FILE
      '';
      input = {
        value = 42;
        name = "example";
      };
    };

    # Task using Python
    "python:hello" = {
      exec = ''print("Hello from Python!")'';
      package = config.languages.python.package;
    };
  };
}
```

```bash
# Run specific task
devenv tasks run myapp:hello

# Run all tasks in namespace
devenv tasks run myapp

# Run with CLI inputs
devenv tasks run myapp:process --input value=100 --input name=test

# List all tasks
devenv tasks list
```

## Scripts

Define reusable scripts available in the development shell.

```nix
# devenv.nix
{ pkgs, config, lib, ... }:

{
  packages = [ pkgs.curl pkgs.jq ];

  scripts = {
    # Simple script
    silly-example.exec = ''
      curl "https://httpbin.org/get?$1" | jq '.args'
    '';

    # Script with runtime packages
    analyze-json = {
      exec = ''
        curl "https://httpbin.org/get?$1" | jq '.args'
      '';
      packages = [ pkgs.curl pkgs.jq ];
      description = "Fetch and analyze JSON";
    };

    # Script with pinned packages
    fetch-data.exec = ''
      ${pkgs.curl}/bin/curl "https://api.example.com/data" | ${pkgs.jq}/bin/jq '.'
    '';

    # Script using different interpreter
    python-hello = {
      exec = ''print("Hello, world!")'';
      package = config.languages.python.package;
      description = "Hello world in Python";
    };

    # Nu shell script
    nushell-greet = {
      exec = ''
        def greet [name] { ["hello" $name] }
        greet "world"
      '';
      package = pkgs.nushell;
      binary = "nu";
      description = "Greet in Nu Shell";
    };
  };

  # List scripts on shell entry
  enterShell = ''
    echo "Available scripts:"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: script:
      "echo '  ${name}: ${script.description or "No description"}'"
    ) config.scripts)}
  '';
}
```

```bash
# Use scripts in shell
devenv shell

# Run script
silly-example foo=1
# Output: { "foo": "1" }

python-hello
# Output: Hello, world!
```

## Git Hooks

Configure pre-commit hooks for code quality and formatting.

```nix
# devenv.nix
{ pkgs, ... }:

{
  git-hooks.hooks = {
    # Built-in hooks
    shellcheck.enable = true;
    black.enable = true;
    prettier.enable = true;
    eslint.enable = true;

    # Rust hooks with custom packages
    clippy.enable = true;
    clippy.packageOverrides.cargo = pkgs.cargo;
    clippy.packageOverrides.clippy = pkgs.clippy;
    clippy.settings.allFeatures = true;

    rustfmt.enable = true;

    # Haskell with custom package
    ormolu.enable = true;
    ormolu.package = pkgs.haskellPackages.ormolu;

    # Custom hook
    unit-tests = {
      enable = true;
      name = "Unit tests";
      entry = "make check";
      files = "\\.(c|h)$";
      types = [ "text" "c" ];
      excludes = [ "irrelevant\\.c" ];
      language = "system";
      pass_filenames = false;
    };
  };
}
```

```bash
# Hooks are installed automatically on shell entry
devenv shell
# Output: pre-commit installed at .git/hooks/pre-commit

# Verify hooks in CI
devenv test
```

## Containers

Generate OCI containers from your development environment.

```nix
# devenv.nix
{ pkgs, config, ... }:

{
  name = "myapp";

  languages.python.enable = true;

  processes = {
    serve.exec = "python -m http.server 8080";
    worker.exec = "python worker.py";
  };

  # Custom container for serving
  containers."serve" = {
    name = "myapp-server";
    startupCommand = config.processes.serve.exec;
  };

  # Production container with only artifacts
  containers."prod" = {
    copyToRoot = ./dist;
    startupCommand = "/mybinary serve";
  };

  # Container for all processes
  containers."processes" = {
    copyToRoot = null;  # Exclude source for smaller image
    registry = "docker://registry.fly.io/";
    defaultCopyArgs = [
      "--dest-creds"
      "x:\"$(${pkgs.flyctl}/bin/flyctl auth token)\""
    ];
  };

  # Conditional packages based on build type
  packages = [ pkgs.openssl ]
    ++ (if (!config.container.isBuilding) then [ pkgs.git ] else []);
}
```

```bash
# Build container
devenv container build shell
# Output: /nix/store/...-image-devenv.json

# Run container locally with Docker
devenv container run shell

# Build and run processes container
devenv container build processes
devenv container run processes

# Copy to registry
devenv container --registry docker:// copy processes

# Copy to fly.io
devenv container --registry docker://registry.fly.io/ \
  --copy-args="--dest-creds x:$(flyctl auth token)" copy processes
```

## Inputs and Dependencies

Configure external inputs for reproducible environments.

```yaml
# devenv.yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  nixpkgs-stable:
    url: github:NixOS/nixpkgs/nixos-23.11
  git-hooks:
    url: github:cachix/git-hooks.nix
```

```nix
# devenv.nix
{ inputs, pkgs, ... }:

let
  pkgs-stable = import inputs.nixpkgs-stable { system = pkgs.stdenv.system; };
in {
  packages = [
    pkgs.git           # Latest from rolling
    pkgs-stable.nginx  # From stable channel
  ];
}
```

```bash
# Update all inputs
devenv update

# Lock is stored in devenv.lock for reproducibility
```

## Composing Environments with Imports

Compose multiple devenv configurations for monorepos.

```yaml
# devenv.yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  devenv:
    url: github:cachix/devenv
    flake: false
imports:
  - ./frontend
  - ./backend
  - devenv/examples/supported-languages
```

```nix
# frontend/devenv.nix
{ pkgs, ... }:
{
  languages.javascript.enable = true;
  processes.frontend.exec = "npm run dev";
}

# backend/devenv.nix
{ pkgs, ... }:
{
  languages.python.enable = true;
  processes.backend.exec = "python manage.py runserver";
}
```

```bash
# At project root: combined environment
devenv shell  # Has both frontend and backend

# Start all processes from both environments
devenv up

# In frontend directory: only frontend environment
cd frontend && devenv shell
```

## Direnv Integration

Automatic shell activation when entering directories.

```bash
# .envrc (create in project root)
#!/usr/bin/env bash

eval "$(devenv direnvrc)"

# Optional: pass flags to devenv
use devenv --option services.postgres.enable:bool true
```

```bash
# Allow direnv to load the environment
direnv allow

# Now shell activates automatically on cd
cd ~/myproject/
# Output:
# direnv: loading ~/myproject/.envrc
# Building shell ...
# Entering shell ...
```

## CLI Commands Reference

Overview of essential devenv CLI commands.

```bash
# Initialize new project
devenv init

# Generate environment using AI
devenv generate

# Enter development shell
devenv shell

# Enter shell with options
devenv shell --impure
devenv shell --option languages.rust.channel:string beta
devenv shell --option services.postgres.enable:bool true
devenv shell --profile backend --profile fast-startup

# Start processes
devenv up
devenv up --strict-ports

# Manage processes
devenv processes start
devenv processes stop

# Run tasks
devenv tasks run myapp:build
devenv tasks run myapp  # Run all in namespace
devenv tasks list

# Run tests
devenv test

# Search packages
devenv search nodejs
devenv search postgresql

# Update inputs
devenv update

# Build outputs
devenv build mypackage

# Environment info
devenv info

# Garbage collection
devenv gc

# Container operations
devenv container build shell
devenv container run processes
devenv container copy prod

# Print version
devenv version

# Launch MCP server for AI assistants
devenv mcp
```

## Environment Variables Reference

Built-in environment variables available in devenv shells.

```nix
# devenv.nix
{ config, ... }:

{
  enterShell = ''
    # Built-in variables
    echo "Project root: $DEVENV_ROOT"
    echo "Dotfile dir: $DEVENV_DOTFILE"    # .devenv/
    echo "State dir: $DEVENV_STATE"         # .devenv/state/
    echo "Runtime dir: $DEVENV_RUNTIME"     # For sockets, temp files
    echo "Profile: $DEVENV_PROFILE"         # Nix store path

    # Git integration
    echo "Git root: ${config.git.root}"
  '';

  processes.api = {
    exec = "python server.py";
    cwd = "${config.git.root}/api";  # Useful in monorepos
  };

  tasks."build:frontend" = {
    exec = "npm run build";
    cwd = "${config.git.root}/frontend";
  };
}
```

devenv is designed for teams seeking consistent, reproducible development environments without the complexity of raw Nix. By centralizing environment configuration in `devenv.nix` and `devenv.yaml`, projects ensure every developer and CI system runs identical tooling, services, and processes. The declarative approach eliminates "works on my machine" issues while providing powerful features like automatic service management, task orchestration, and container generation.

Common integration patterns include: using direnv for automatic shell activation, defining tasks for build/test workflows, composing environments for monorepos, and generating containers for deployment. The tool works seamlessly with existing workflows - add a `devenv.nix` to any project, run `devenv shell`, and start developing with properly configured tools, databases, and services all managed through a single configuration file.