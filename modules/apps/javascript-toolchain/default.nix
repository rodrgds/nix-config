{
  config,
  constants,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.javascript-toolchain;
  inherit (constants) homeDir isDarwin isLinux;

  installDir = cfg.npm.installDir;
  installRoot = "${homeDir}/${installDir}";
  npmBinDir = "${installRoot}/bin";
  lockRoot =
    if isDarwin then
      "${homeDir}/Library/Application Support/rgo-maintenance/locks"
    else
      "${homeDir}/.local/state/rgo-maintenance/locks";

  cliPackages = builtins.attrValues cfg.npm.cliPackages;
  managedPackageSpecs = map (cliPackage: cliPackage.package) cliPackages;
  retiredPackages = lib.unique (
    cfg.npm.retiredPackages ++ lib.flatten (map (cliPackage: cliPackage.retiredPackages) cliPackages)
  );
  retiredPackagePaths = map (package: "lib/node_modules/${package}") retiredPackages;
  managedBinaries = lib.unique (lib.flatten (map (cliPackage: cliPackage.binaries) cliPackages));
  bootstrapFiles = lib.unique (lib.flatten (map (cliPackage: cliPackage.bootstrapFiles) cliPackages));
  postUpdateHooks = lib.concatStringsSep "\n" (
    lib.flatten (map (cliPackage: cliPackage.postUpdate) cliPackages)
  );

  toolchainEnabled = cfg.enable || cfg.node.enable || cfg.bun.enable || cliPackages != [ ];

  updateScript = pkgs.writeShellApplication {
    name = "update-javascript-toolchain";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.flock
      pkgs.git
      pkgs.gnused
      cfg.node.package
    ];
    text = ''
      set -euo pipefail

      install_root=${lib.escapeShellArg installRoot}
      lock_root=${lib.escapeShellArg lockRoot}
      lock_file="$lock_root/javascript-toolchain-update.lock"

      mkdir -p "$install_root" "$lock_root"
      exec 9>"$lock_file"
      if ! flock --nonblock 9; then
        echo "javascript-toolchain: update already running, skipping" >&2
        exit 0
      fi

      export PATH="${cfg.node.binDir}:$PATH"

      managed_packages=(
      ${lib.concatMapStringsSep "\n" (package: "  ${lib.escapeShellArg package}") managedPackageSpecs}
      )
      retired_packages=(
      ${lib.concatMapStringsSep "\n" (package: "  ${lib.escapeShellArg package}") retiredPackages}
      )

      if [ "''${#retired_packages[@]}" -gt 0 ]; then
        npm uninstall \
          --global \
          --prefix "$install_root" \
          "''${retired_packages[@]}" \
          >/dev/null 2>&1 || true
      fi

      if [ "''${#managed_packages[@]}" -gt 0 ]; then
        npm install \
          --global \
          --prefix "$install_root" \
          --no-audit \
          --no-fund \
          "''${managed_packages[@]}"
      fi

      ${postUpdateHooks}
    '';
  };
in
{
  imports = [
    (lib.mkAliasOptionModule
      [
        "apps"
        "nodejs"
        "enable"
      ]
      [
        "apps"
        "javascript-toolchain"
        "node"
        "enable"
      ]
    )
    (lib.mkAliasOptionModule
      [
        "apps"
        "bun"
        "enable"
      ]
      [
        "apps"
        "javascript-toolchain"
        "bun"
        "enable"
      ]
    )
    (lib.mkRemovedOptionModule [
      "apps"
      "pnpm"
      "enable"
    ] "pnpm is no longer managed here because no first-party project uses it.")
  ];

  options.apps.javascript-toolchain = {
    enable = lib.mkEnableOption "shared JavaScript toolchain ownership";

    node = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install Node.js and npm.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nodejs;
        description = "Node.js package used for the shared toolchain.";
      };

      binDir = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${cfg.node.package}/bin";
        description = "Absolute directory containing the toolchain's Node.js binaries.";
      };

      binPath = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${cfg.node.package}/bin/node";
        description = "Absolute Node.js binary path.";
      };
    };

    bun = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install Bun alongside Node.js.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bun;
        description = "Bun package used for the shared toolchain.";
      };
    };

    npm = {
      installDir = lib.mkOption {
        type = lib.types.str;
        default = ".local/share/npm-global";
        description = "Home-relative prefix for managed global npm packages.";
      };

      installRoot = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = installRoot;
        description = "Absolute path to the managed global npm prefix.";
      };

      binDir = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = npmBinDir;
        description = "Absolute path to the managed global npm bin directory.";
      };

      binPath = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${cfg.node.package}/bin/npm";
        description = "Absolute npm binary path.";
      };

      retiredPackages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "@google/gemini-cli" ];
        description = "Global npm packages that should be removed during migration.";
      };

      cliPackages = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                package = lib.mkOption {
                  type = lib.types.str;
                  description = "npm package spec installed into the shared global prefix.";
                };

                binaries = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ name ];
                  description = "Executables expected in the shared npm bin directory.";
                };

                bootstrapFiles = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Paths under the install root that must exist after bootstrap.";
                };

                retiredPackages = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Packages uninstalled before this managed package is updated.";
                };

                postUpdate = lib.mkOption {
                  type = lib.types.listOf lib.types.lines;
                  default = [ ];
                  description = "Shell fragments run after the shared npm install step.";
                };
              };
            }
          )
        );
        default = { };
        description = "Declarative npm CLI catalog owned by the shared JavaScript toolchain.";
      };
    };
  };

  config = lib.mkIf toolchainEnabled {
    environment.systemPackages = [
      cfg.node.package
    ]
    ++ lib.optionals cfg.bun.enable [ cfg.bun.package ];

    home-manager.users.${username} =
      { lib, ... }:
      lib.mkMerge [
        {
          home.packages = [ updateScript ];

          home.sessionPath = [ "$HOME/${installDir}/bin" ];

          home.file.".npmrc".text = "prefix=${installRoot}\n";

          home.activation.bootstrapJavascriptToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            needs_bootstrap=0

            for bin_name in ${lib.escapeShellArgs managedBinaries}; do
              if [ ! -x ${lib.escapeShellArg npmBinDir}/"$bin_name" ]; then
                needs_bootstrap=1
                break
              fi
            done

            if [ "$needs_bootstrap" = "0" ]; then
              for rel_path in ${lib.escapeShellArgs bootstrapFiles}; do
                if [ ! -e ${lib.escapeShellArg installRoot}/"$rel_path" ]; then
                  needs_bootstrap=1
                  break
                fi
              done
            fi

            if [ "$needs_bootstrap" = "0" ]; then
              for retired_path in ${lib.escapeShellArgs retiredPackagePaths}; do
                if [ -e ${lib.escapeShellArg installRoot}/"$retired_path" ]; then
                  needs_bootstrap=1
                  break
                fi
              done
            fi

            if [ "$needs_bootstrap" = "1" ]; then
              ${updateScript}/bin/update-javascript-toolchain
            fi
          '';
        }

        (lib.optionalAttrs isLinux {
          systemd.user.services.update-javascript-toolchain = {
            Unit.Description = "Update shared JavaScript CLI toolchain";
            Service = {
              Type = "oneshot";
              ExecStart = "${updateScript}/bin/update-javascript-toolchain";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          };

          systemd.user.timers.update-javascript-toolchain = {
            Unit.Description = "Periodically update shared JavaScript CLI toolchain";
            Timer = {
              OnBootSec = "15m";
              OnUnitActiveSec = "1d";
              RandomizedDelaySec = "1h";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })

        (lib.optionalAttrs isDarwin {
          launchd.agents.update-javascript-toolchain = {
            enable = true;
            config = {
              Label = "pt.rgo.update-javascript-toolchain";
              ProgramArguments = [ "${updateScript}/bin/update-javascript-toolchain" ];
              StartCalendarInterval = lib.hm.darwin.mkCalendarInterval "daily";
              ProcessType = "Background";
              LowPriorityIO = true;
              StandardOutPath = "/tmp/update-javascript-toolchain.log";
              StandardErrorPath = "/tmp/update-javascript-toolchain.err";
              EnvironmentVariables = {
                HOME = homeDir;
              };
            };
          };
        })
      ];
  };
}
