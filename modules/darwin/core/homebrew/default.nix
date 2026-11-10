# Homebrew infrastructure. App modules own their formulae and casks.
#
# Rebuilds only install and remove declared packages; they never run
# `brew update` or upgrade apps, which made activation slow and restarted
# running apps. GUI casks marked auto_updates keep their own updaters, and a
# daily background job upgrades everything else.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.darwin.core.homebrew;
  brewPrefix = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";

in
{
  options.darwin.core.homebrew = {
    enable = lib.mkEnableOption "Enable Homebrew";
  };

  config = lib.mkIf cfg.enable {
    # Homebrew configuration
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        cleanup = "zap";
        upgrade = false;
      };

      # Taps to add
      # Note: homebrew/cask, homebrew/cask-versions, and homebrew/services
      # are deprecated - casks and services are now built into Homebrew core
      taps = [
        {
          name = "nikitabobko/tap";
          trusted = true;
        }
        {
          name = "FelixKratz/formulae";
          trusted = true;
        }
      ];
    };

    launchd.user.agents.homebrew-upgrade.serviceConfig = {
      Label = "pt.rgo.homebrew-upgrade";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "${brewPrefix}/bin/brew update --quiet && ${brewPrefix}/bin/brew upgrade"
      ];
      StartCalendarInterval = [
        {
          Hour = 12;
          Minute = 30;
        }
      ];
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/tmp/homebrew-upgrade.log";
      StandardErrorPath = "/tmp/homebrew-upgrade.log";
    };

    # Homebrew 4.6+ refuses formulae/casks from third-party taps until they are
    # explicitly trusted. Do this before nix-darwin runs `brew bundle`, so a
    # fresh activation can install packages from our configured taps.
    system.activationScripts.homebrew.text = lib.mkBefore ''
      if [ -x "${brewPrefix}/bin/brew" ]; then
        echo >&2 "trusting Homebrew taps..."
        PATH="${brewPrefix}/bin:$PATH" \
        sudo \
          --preserve-env=PATH \
          --user=${lib.escapeShellArg config.system.primaryUser} \
          --set-home \
          env HOMEBREW_NO_AUTO_UPDATE=1 \
          bash -c '
            if brew help trust >/dev/null 2>&1; then
              for tap in \
                beeper/tap \
                felixkratz/formulae \
                nikitabobko/tap
              do
                brew trust "$tap" >/dev/null 2>&1 || true
              done
            fi
          '
      fi
    '';
  };
}
