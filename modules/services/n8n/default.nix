# n8n workflow automation with Chromium support
# Uses custom n8n image with Chromium and node-vibrant
#
# To build the custom image, run on the VPS:
#   sudo /etc/n8n-custom/build.sh
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.n8n;

  n8nPort = 5678;
  postgresPort = 5432;

  # Use custom image if built locally, otherwise use official
  # To build: ssh to VPS and run:
  #   sudo podman build -t localhost/n8n-custom:latest /etc/n8n-custom/
  n8nImage = "localhost/n8n-custom:latest";

  # Custom Dockerfile content
  # Since the official n8n image is minimal/distroless without package manager,
  # we build from Alpine base and install n8n + custom packages
  dockerfileContent = ''
    FROM node:22-alpine

    # Set environment variables
    ENV NODE_OPTIONS="--no-warnings" \
        NODE_FUNCTION_ALLOW_EXTERNAL=* \
        NODE_FUNCTION_ALLOW_BUILTIN=* \
        NODE_PATH=/usr/local/lib/node_modules \
        NODE_ENV=production \
        N8N_PORT=5678 \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

    # Install system dependencies
    RUN apk add --no-cache \
        chromium \
        nss \
        freetype \
        harfbuzz \
        ca-certificates \
        ttf-freefont \
        git \
        curl \
        python3 \
        py3-pip \
        && rm -rf /var/cache/apk/*

    # Install n8n and custom npm packages globally
    # Using @tensorflow/tfjs (WASM) instead of tfjs-node to avoid Node 22 compatibility issues
    RUN npm install -g n8n node-vibrant @vladmandic/face-api @tensorflow/tfjs sharp --unsafe-perm

    # Create node user with specific UID/GID to match volume permissions
    RUN deluser --remove-home node 2>/dev/null || true && \
        addgroup -g 1000 node && \
        adduser -u 1000 -G node -s /bin/sh -D node && \
        mkdir -p /home/node/.n8n && \
        chown -R node:node /home/node

    # Switch to node user
    USER node

    # Set working directory
    WORKDIR /home/node

    # Expose port
    EXPOSE 5678

    # Start n8n
    CMD ["n8n"]
  '';
in
{
  options.vps.n8n = {
    enable = lib.mkEnableOption "n8n workflow automation";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "n8n.rgo.pt";
      description = "Domain for n8n";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Lisbon";
      description = "Timezone for n8n";
    };

    useCustomImage = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use custom n8n image with Chromium and node-vibrant (auto-builds on first start)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories and deploy Dockerfile
    systemd.tmpfiles.rules = [
      "d /var/lib/n8n 0750 root root -"
      "d /var/lib/n8n/postgres 0750 999 999 -" # postgres user
      "d /var/lib/n8n/data 0750 1000 1000 -" # n8n user (node)
      "d /var/backup/n8n 0750 root root -" # backup directory
      "d /opt/n8n-custom 0755 root root -" # Dockerfile location
    ];

    # Deploy custom Dockerfile to VPS
    environment.etc."n8n-custom/Dockerfile" = lib.mkIf cfg.useCustomImage {
      text = dockerfileContent;
      mode = "0644";
    };

    # Create a build helper script
    environment.etc."n8n-custom/build.sh" = lib.mkIf cfg.useCustomImage {
      text = ''
        #!/usr/bin/env bash
        set -e
        echo "🔨 Building custom n8n image with Chromium and node-vibrant..."
        cd /etc/n8n-custom
        podman build -t localhost/n8n-custom:latest .
        echo "✅ Custom n8n image built successfully!"
        echo "🔄 Restarting n8n service..."
        systemctl restart podman-n8n
        echo "✅ Done! n8n is now using the custom image."
      '';
      mode = "0755";
    };

    # Postgres 16 with pgvector (disabled - using SQLite instead)
    # Uncomment this if you want to switch to PostgreSQL
    # virtualisation.oci-containers.containers.n8n-postgres = {
    #   image = "docker.io/pgvector/pgvector:pg16";
    #
    #   environment = {
    #     POSTGRES_USER = config.sops.placeholder.n8n_postgres_user;
    #     POSTGRES_DB = config.sops.placeholder.n8n_postgres_db;
    #     POSTGRES_PASSWORD_FILE = "/run/secrets/postgres_password";
    #   };
    #
    #   volumes = [
    #     "/var/lib/n8n/postgres:/var/lib/postgresql/data"
    #   ];
    #
    #   ports = [
    #     "127.0.0.1:${toString postgresPort}:5432"
    #   ];
    #
    #   extraOptions = [
    #     "--network=podman"
    #     "--mount=type=bind,source=${config.sops.templates.n8n-postgres-password.path},target=/run/secrets/postgres_password,ro"
    #   ];
    # };

    # Auto-build custom image systemd service
    systemd.services.n8n-custom-image-build = lib.mkIf cfg.useCustomImage {
      description = "Build custom n8n image with Chromium";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "build-n8n-custom" ''
          if ! ${pkgs.podman}/bin/podman image exists localhost/n8n-custom:latest 2>/dev/null; then
            echo "🔨 Building custom n8n image with Chromium and node-vibrant..."
            cd /etc/n8n-custom
            ${pkgs.podman}/bin/podman build -t localhost/n8n-custom:latest .
            echo "✅ Custom n8n image built successfully!"
          else
            echo "✅ Custom n8n image already exists"
          fi
        '';
      };
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-n8n.service" ];
    };

    # Add dependency to podman-n8n service
    systemd.services.podman-n8n = lib.mkIf cfg.useCustomImage {
      after = [ "n8n-custom-image-build.service" ];
      requires = [ "n8n-custom-image-build.service" ];
    };

    # n8n application
    virtualisation.oci-containers.containers.n8n = {
      image = if cfg.useCustomImage then n8nImage else "docker.n8n.io/n8nio/n8n:latest";
      imageFile = lib.mkIf cfg.useCustomImage null; # Don't pull from registry if using custom

      environment = {
        # Database configuration
        DB_TYPE = "sqlite";
        # DB_TYPE = "postgresdb";
        # DB_POSTGRESDB_HOST = "n8n-postgres";
        # DB_POSTGRESDB_PORT = "5432";
        # DB_POSTGRESDB_DATABASE = config.sops.placeholder.n8n_postgres_db;
        # DB_POSTGRESDB_USER = config.sops.placeholder.n8n_postgres_user;
        # DB_POSTGRESDB_PASSWORD_FILE = "/run/secrets/postgres_password";

        # n8n configuration
        N8N_BASIC_AUTH_ACTIVE = "true";
        N8N_ENCRYPTION_KEY_FILE = "/run/secrets/n8n_encryption_key";

        # URL configuration
        N8N_EDITOR_BASE_URL = "https://${cfg.domain}";
        WEBHOOK_URL = "https://${cfg.domain}";
        N8N_HOST = cfg.domain;
        N8N_PORT = "5678";
        N8N_PROTOCOL = "https";

        # Timezone
        GENERIC_TIMEZONE = cfg.timezone;
        TZ = cfg.timezone;

        # Node/Puppeteer configuration for Chrome/Chromium support
        NODE_OPTIONS = "--no-warnings";
        NODE_FUNCTION_ALLOW_EXTERNAL = "*";
        NODE_FUNCTION_ALLOW_BUILTIN = "*";
        NODE_PATH = "/usr/local/lib/node_modules";
        NODE_ENV = "production";
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = "true";
        PUPPETEER_EXECUTABLE_PATH = "/usr/bin/chromium-browser";
      };

      volumes = [
        "/var/lib/n8n/data:/home/node/.n8n"
      ];

      ports = [
        "127.0.0.1:${toString n8nPort}:5678"
      ];

      # Disabled postgres dependency since we're using SQLite
      # dependsOn = [ "n8n-postgres" ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.n8n-encryption-key.path},target=/run/secrets/n8n_encryption_key,ro"
      ];
    };

    # Secrets management
    sops.templates = {
      # Postgres password template (for future use if switching to PostgreSQL)
      # "n8n-postgres-password" = {
      #   content = config.sops.placeholder.n8n_postgres_password;
      #   mode = "0444";  # World-readable for container access
      # };
      "n8n-encryption-key" = {
        content = config.sops.placeholder.n8n_encryption_key;
        mode = "0444"; # World-readable for container access
      };
    };

    # Secrets are mounted directly via extraOptions above

    # n8n uses SQLite, so we backup the data directory instead
    # The SQLite database is at /var/lib/n8n/data/database.sqlite
    # File-based backup is handled by Hetzner's backup system

    # Update Caddy internal ports
    vps.caddy.internalPorts.n8n = n8nPort;
  };
}
