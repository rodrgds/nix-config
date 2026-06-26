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
  inherit (constants) isDarwin;
in
{
  options.apps.bash = {
    enable = lib.mkEnableOption "Enable Bash";
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
          "erasedups"
        ];

        shellOptions = [
          "histappend"
          "checkwinsize"
          "globstar"
        ];

        profileExtra = lib.optionalString isDarwin ''
          if [ -d /opt/homebrew/bin ]; then
            export PATH="/opt/homebrew/bin:$PATH"
          fi

          if [ -d /opt/homebrew/sbin ]; then
            export PATH="/opt/homebrew/sbin:$PATH"
          fi

          if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          fi
        '';

        initExtra = ''
          if [ -z "$BASH_VERSION" ]; then
            return 2>/dev/null || exit 0
          fi

          export CLICOLOR=1
          export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
          alias ls="ls -G"

          # Colored grep
          alias grep="grep --color=auto"
          alias fgrep="fgrep --color=auto"
          alias egrep="egrep --color=auto"
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
          export HISTTIMEFORMAT="%F %T  "

          # Sync history across sessions after every command
          PROMPT_COMMAND="history -a; history -n; ''${PROMPT_COMMAND:-}"

          # Shell options
          set -o vi
          set -o ignoreeof
          shopt -s autocd
          shopt -s extglob
          shopt -s globstar
          shopt -s checkwinsize
          shopt -s cdspell

          # Readline bindings
          bind '"\e[A": history-search-backward'
          bind '"\e[B": history-search-forward'
          bind "set completion-ignore-case on"
          bind "set show-all-if-ambiguous on"
          bind "set menu-complete-display-prefix on"
          bind "set colored-stats on"
          bind "set visible-stats on"
          bind 'TAB:menu-complete'
          bind '"\\e[Z":menu-complete-backward'

          # fzf keybindings
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

      programs.atuin = {
        enable = true;
        enableBashIntegration = true;
        settings = {
          style = "compact";
          search_mode = "fuzzy";
          filter_mode = "global";
          filter_mode_shell_up_key_binding = "directory";
          show_preview = true;
          exit_mode = "return-query";
          history_filter = [
            "^ls$"
            "^cd$"
            "^pwd$"
            "^exit$"
            "^clear$"
          ];
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
