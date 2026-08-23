# Podman container runtime for VPS
# Uses virtualisation.oci-containers for declarative container management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.podman;
  podmanImageCleanup = pkgs.writeShellApplication {
    name = "podman-image-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.podman
      pkgs.util-linux
    ];
    text = ''
      mode=""
      lock_held=false

      usage() {
        echo "usage: podman-image-cleanup (--immediate | --older-than-24h) [--lock-held]" >&2
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --immediate)
            [ -z "$mode" ] || { usage; exit 2; }
            mode=immediate
            ;;
          --older-than-24h)
            [ -z "$mode" ] || { usage; exit 2; }
            mode=older-than-24h
            ;;
          --lock-held)
            lock_held=true
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            echo "podman-image-cleanup: unknown argument: $1" >&2
            usage
            exit 2
            ;;
        esac
        shift
      done
      [ -n "$mode" ] || { usage; exit 2; }

      if [ "$lock_held" = false ]; then
        exec ${pkgs.util-linux}/bin/flock --exclusive /run/podman-maintenance.lock \
          "$0" "--$mode" --lock-held
      fi

      work_dir="$(mktemp -d)"
      trap 'rm -rf "$work_dir"' EXIT
      protected="$work_dir/protected"
      candidates="$work_dir/candidates"
      : > "$protected"

      normalize_image_ids() {
        jq -Rr 'select(length > 0)
          | if test("^sha256:[0-9a-f]{64}$") then .
            elif test("^[0-9a-f]{64}$") then "sha256:" + .
            else error("malformed image ID: " + .)
            end'
      }

      # Snapshot immutable full image IDs directly. This covers regular,
      # stopped, created, and external Buildah containers without a racy second
      # inspect after short-lived containers have disappeared.
      podman container list --all --external --no-trunc --format '{{.ImageID}}' \
        | normalize_image_ids \
        >> "$protected"

      # Preserve deployment aliases even for helpers such as migration images
      # which intentionally have no persistent container.
      all_image_ids_file="$work_dir/all-image-ids"
      podman image list --all --quiet --no-trunc \
        | normalize_image_ids \
        | sort -u > "$all_image_ids_file"
      mapfile -t all_image_ids < "$all_image_ids_file"
      for image_id in "''${all_image_ids[@]}"; do
        [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || {
          echo "podman-image-cleanup: refusing malformed image ID: $image_id" >&2
          exit 1
        }
        podman image inspect "$image_id" \
          | jq -r '.[0] | select(any(.RepoTags[]?; test(":(latest|rollback)$"))) | .Id
            | if type != "string" then error("tagged image ID is not a string")
              elif test("^sha256:[0-9a-f]{64}$") then .
              elif test("^[0-9a-f]{64}$") then "sha256:" + .
              else error("tagged image has malformed image ID: " + .)
              end' \
          >> "$protected"
      done
      sort -u -o "$protected" "$protected"

      if [ "$mode" = immediate ]; then
        printf '%s\n' "''${all_image_ids[@]}" > "$candidates"
      else
        podman image list --all --quiet --no-trunc --filter until=24h \
          | normalize_image_ids \
          | sort -u > "$candidates"
      fi

      declare -A protected_ids=()
      while IFS= read -r protected_id; do
        [ -n "$protected_id" ] || continue
        [[ "$protected_id" =~ ^sha256:[0-9a-f]{64}$ ]] || {
          echo "podman-image-cleanup: refusing malformed protected ID: $protected_id" >&2
          exit 1
        }
        protected_ids["$protected_id"]=1
      done < "$protected"

      removed=0
      while IFS= read -r image_id; do
        [ -n "$image_id" ] || continue
        [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || {
          echo "podman-image-cleanup: refusing malformed candidate ID: $image_id" >&2
          exit 1
        }
        if ! podman image exists "$image_id"; then
          echo "podman-image-cleanup: skipping already removed image $image_id"
          continue
        fi
        if [[ -n "''${protected_ids[$image_id]+present}" ]]; then
          echo "podman-image-cleanup: preserving protected image $image_id"
          continue
        fi
        echo "podman-image-cleanup: removing unprotected image $image_id ($mode)"
        podman image rm "$image_id"
        removed=$((removed + 1))
      done < "$candidates"

      echo "podman-image-cleanup: removed $removed image(s); pruning build cache"
      podman image prune --force --build-cache
      echo "podman-image-cleanup: cleanup complete ($mode)"
    '';
  };
in
{
  options.services.podman = {
    enable = lib.mkEnableOption "Enable Podman";
  };

  config = lib.mkIf cfg.enable {
    sops.templates.packages-registry-token = {
      content = config.sops.placeholder.packages_ghcr_token;
      mode = "0400";
      restartUnits = [ "packages-registry-login.service" ];
    };

    systemd.services.packages-registry-login = {
      description = "Authenticate rootful Podman to private GHCR packages";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # Stay inactive after success so refreshing credentials cannot stop
        # running services that require this login helper.
        ExecStart = pkgs.writeShellScript "packages-registry-login" ''
          exec ${pkgs.podman}/bin/podman login ghcr.io \
            --username rodrgds \
            --password-stdin < ${config.sops.templates.packages-registry-token.path}
        '';
      };
    };

    # Enable Podman
    virtualisation.podman = {
      enable = true;

      # Create a docker-compatible alias
      dockerCompat = true;

      # Required for containers under podman
      defaultNetwork.settings.dns_enabled = true;
    };

    # Use podman for oci-containers backend
    virtualisation.oci-containers.backend = "podman";

    # Install the shared rootful image cleanup command alongside Podman tools.
    environment.systemPackages = [
      pkgs.podman-compose
      podmanImageCleanup
    ];

    # Failed deployment candidates remain available for diagnosis until this
    # conservative age-filtered sweep. Deployments run immediate mode on success.
    systemd.services.podman-image-cleanup = {
      description = "Remove abandoned rootful Podman images and build cache";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${podmanImageCleanup}/bin/podman-image-cleanup --older-than-24h";
      };
    };

    systemd.timers.podman-image-cleanup = {
      description = "Daily abandoned Podman image cleanup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Storage for containers
    # Persistent data goes under /var/lib/<service>
    # This is managed by individual service modules
  };
}
