{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.core.frozen-packages;
  inherit (constants) isLinux;

  packageType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable this frozen package entry.";
        };

        mode = lib.mkOption {
          type = lib.types.enum [
            "managed"
            "frozen"
          ];
          default = "managed";
          description = ''
            "managed" installs package in the system closure. "frozen" installs
            a wrapper that runs a previously pinned store path.
          '';
        };

        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Package to install in managed mode.";
        };

        command = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Command exposed by the package and wrapper.";
        };

        executablePath = lib.mkOption {
          type = lib.types.str;
          default = "/bin/${name}";
          description = "Executable path inside the pinned package output.";
        };

        rootName = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the persistent GC root under /nix/var/nix/gcroots.";
        };
      };
    }
  );

  enabledEntries = lib.filterAttrs (_: entry: entry.enable) cfg.packages;

  mkRoot = entry: "/nix/var/nix/gcroots/${entry.rootName}";

  mkFreezeScript =
    name: entry:
    pkgs.writeShellScriptBin "freeze-${name}" ''
      set -euo pipefail

      current="''${1:-}"
      if [ -z "$current" ]; then
        if [ -x /run/current-system/sw/bin/${entry.command} ]; then
          current=/run/current-system/sw/bin/${entry.command}
        elif command -v ${entry.command} >/dev/null 2>&1; then
          current="$(command -v ${entry.command})"
        else
          echo "Could not find ${entry.command}. Pass the executable path explicitly." >&2
          exit 1
        fi
      fi

      resolved="$(readlink -f "$current")"
      if [ ! -x "$resolved" ]; then
        echo "Resolved executable is not executable: $resolved" >&2
        exit 1
      fi

      case "$resolved" in
        /nix/store/*) ;;
        *)
          echo "Resolved executable is not in /nix/store: $resolved" >&2
          exit 1
          ;;
      esac

      store_entry="''${resolved#/nix/store/}"
      store_path="/nix/store/''${store_entry%%/*}"

      sudo mkdir -p /nix/var/nix/gcroots
      sudo nix-store --add-root ${mkRoot entry} --indirect --realise "$store_path"
      echo "Frozen ${name} at ${mkRoot entry} -> $store_path"
    '';

  mkWrapper =
    name: entry:
    pkgs.writeShellScriptBin entry.command ''
      set -euo pipefail

      executable="${mkRoot entry}${entry.executablePath}"
      if [ ! -x "$executable" ]; then
        echo "Frozen ${name} executable is missing: $executable" >&2
        echo "Run: freeze-${name}" >&2
        exit 1
      fi

      exec "$executable" "$@"
    '';

  mkPackages =
    name: entry:
    [
      (mkFreezeScript name entry)
    ]
    ++ lib.optionals (entry.mode == "managed" && entry.package != null) [
      entry.package
    ]
    ++ lib.optionals (entry.mode == "frozen") [
      (mkWrapper name entry)
    ];

  mkActivation = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: entry:
      if entry.mode == "frozen" then
        ''
          if [ ! -e ${mkRoot entry} ] && [ -x /run/current-system/sw/bin/${entry.command} ]; then
            resolved="$(${pkgs.coreutils}/bin/readlink -f /run/current-system/sw/bin/${entry.command})"
            store_entry="''${resolved#/nix/store/}"
            store_path="/nix/store/''${store_entry%%/*}"
            mkdir -p /nix/var/nix/gcroots
            ${pkgs.nix}/bin/nix-store --add-root ${mkRoot entry} --indirect --realise "$store_path" || true
          fi
        ''
      else
        ''
          # A managed package is already protected by the system closure. An
          # older frozen root would only pin a duplicate package indefinitely.
          if [ -e ${mkRoot entry} ] || [ -L ${mkRoot entry} ]; then
            echo "Removing obsolete managed-package GC root: ${mkRoot entry}"
            rm -f ${mkRoot entry}
          fi
        ''
    ) enabledEntries
  );
in
{
  options.core.frozen-packages = {
    packages = lib.mkOption {
      type = lib.types.attrsOf packageType;
      default = { };
      description = "Packages that can be switched between managed and frozen GC-root-backed mode.";
    };
  };

  config = lib.mkIf (isLinux && enabledEntries != { }) {
    environment.systemPackages = lib.flatten (lib.mapAttrsToList mkPackages enabledEntries);

    system.activationScripts.freezePackages = mkActivation;
  };
}
