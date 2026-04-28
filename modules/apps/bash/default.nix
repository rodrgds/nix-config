{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.bash;
  inherit (constants) isDarwin colors;
in
{
  options.apps.bash = {
    enable = lib.mkEnableOption "Enable Bash shell with gruvbox theme and all goodies";
  };

  config = lib.mkIf cfg.enable {
    programs.bash.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.bash = {
        enable = true;
        enableCompletion = true;

        historySize = 100000;
        historyFile = "$HOME/.bash_history";
        historyFileSize = 100000;
        historyControl = [
          "ignoredups"
          "ignorespace"
        ];

        shellOptions = [
          "histappend"
          "checkwinsize"
          "globstar"
        ];

        # profileExtra runs in .bash_profile (login shells — macOS Terminal)
        profileExtra = ''
          # Source .bashrc for login shells (required on macOS where
          # Terminal opens login shells that skip .bashrc by default)
          if [ -f "$HOME/.bashrc" ]; then
            source "$HOME/.bashrc"
          fi
        ''
        + lib.optionalString isDarwin ''
          # Add Homebrew to PATH on macOS
          if [ -d /opt/homebrew/bin ]; then
            export PATH="/opt/homebrew/bin:$PATH"
          fi

          if [ -d /opt/homebrew/sbin ]; then
            export PATH="/opt/homebrew/sbin:$PATH"
          fi

          # Initialize Homebrew shell environment if available
          if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          fi
        '';

        # initExtra runs in .bashrc (both login and non-login shells)
        initExtra = ''
          # Only run in actual bash, skip if sourced by zsh/sh
          if [ -z "$BASH_VERSION" ]; then
            return 2>/dev/null || exit 0
          fi

          # Gruvbox LS_COLORS + always colorize ls
          export CLICOLOR=1
          export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
          alias ls="ls -G"

          # Colored grep
          alias grep="grep --color=auto"
          alias fgrep="fgrep --color=auto"
          alias egrep="egrep --color=auto"
          export GREP_COLOR="1;33"

          # Colored man pages
          export LESS_TERMCAP_mb=$'\e[1;31m'
          export LESS_TERMCAP_md=$'\e[0;33m'
          export LESS_TERMCAP_me=$'\e[0m'
          export LESS_TERMCAP_se=$'\e[0m'
          export LESS_TERMCAP_so=$'\e[1;44;33m'
          export LESS_TERMCAP_ue=$'\e[0m'
          export LESS_TERMCAP_us=$'\e[1;32m'

          # Shell options
          set -o vi
          set -o ignoreeof
          shopt -s autocd
          shopt -s extglob
          shopt -s globstar
          shopt -s checkwinsize
          shopt -s cdspell

          # Readline: history search with up/down, case-insensitive completion
          bind '"\e[A": history-search-backward'
          bind '"\e[B": history-search-forward'
          bind "set completion-ignore-case on"
          bind "set show-all-if-ambiguous on"
          bind "set menu-complete-display-prefix on"
          bind "set colored-stats on"
          bind "set visible-stats on"

          # Tab cycles through completions instead of listing them first
          bind 'TAB:menu-complete'
          bind '"\\e[Z":menu-complete-backward'

          # Enable fzf keybindings if available
          if [[ -z "''${FZF_BASH_INTEGRATION_LOADED:-}" ]] && command -v fzf &> /dev/null; then
            source ${pkgs.fzf}/share/fzf/key-bindings.bash
            source ${pkgs.fzf}/share/fzf/completion.bash
          fi
        '';

        sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less -R";
          LESS = "-R";
        };
      };

      home.sessionVariables = {
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
      };

      programs.fzf.enableBashIntegration = true;

      programs.zoxide.enableBashIntegration = true;

      programs.direnv.enableBashIntegration = true;
    };
  };
}
