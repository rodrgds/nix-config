{
  lib,
  config,
  constants,
  pkgs,
  ...
}:
let
  cfg = config.darwin.core.networking;
  nasMarker = "# nix-darwin:rgo-nas";
  nasFstabLine = "${cfg.nas.server}:${cfg.nas.export} ${cfg.nas.mountPoint} nfs rw,nfsvers=4,resvport 0 0";
  rewriteNasFstab = addEntry: ''
    fstab=/etc/fstab
    marker=${lib.escapeShellArg nasMarker}
    desiredLine=${lib.escapeShellArg nasFstabLine}

    if [ -L "$fstab" ]; then
      echo >&2 "error: refusing to replace symlinked $fstab while managing the NAS automount"
      exit 1
    fi

    tmp="$(${pkgs.coreutils}/bin/mktemp /etc/fstab.nix-darwin-nas.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

    if [ -f "$fstab" ]; then
      ${pkgs.gawk}/bin/awk -v marker="$marker" '
        skipNext { skipNext = 0; next }
        index($0, marker) {
          if ($0 == marker) skipNext = 1
          next
        }
        { print }
      ' "$fstab" > "$tmp"
    fi

    ${lib.optionalString addEntry ''
      printf '%s\n%s\n' "$marker" "$desiredLine" >> "$tmp"
    ''}

    if [ ! -f "$fstab" ] || ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$fstab"; then
      ${pkgs.coreutils}/bin/chown root:wheel "$tmp"
      ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
      ${pkgs.coreutils}/bin/mv -f "$tmp" "$fstab"
      trap - EXIT
    fi

    /usr/sbin/automount -vc
  '';
in
{
  options.darwin.core.networking = {
    enable = lib.mkEnableOption "Enable networking";

    tailscale = {
      enable = lib.mkEnableOption "Enable Tailscale";
    };

    nas = {
      enable = lib.mkEnableOption "the on-demand NAS mount";

      server = lib.mkOption {
        type = lib.types.str;
        default = "rgo-nas.long-barometric.ts.net";
        description = "Tailscale MagicDNS name of the NAS.";
      };

      export = lib.mkOption {
        type = lib.types.str;
        default = "/volume1/homes/kraktoos";
        description = "NFS export path on the NAS.";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "${constants.homeDir}/nas";
        description = "Local path exposed by the macOS automounter.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.nas.enable || cfg.tailscale.enable;
        message = "darwin.core.networking.nas requires Tailscale";
      }
    ];

    # Install Tailscale via Homebrew when enabled
    homebrew.casks = lib.mkIf cfg.tailscale.enable [ "tailscale-app" ];

    # macOS's default /etc/auto_master includes the /- -static map, which
    # turns non-net /etc/fstab entries into direct, on-demand mounts. Preserve
    # the Nix installer's existing /nix entry and manage only our tagged line.
    system.activationScripts.extraActivation.text = lib.mkAfter (
      if cfg.nas.enable then rewriteNasFstab true else rewriteNasFstab false
    );

    # Hostname is set in the host-specific configuration
  };
}
