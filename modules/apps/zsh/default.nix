{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.zsh;
  inherit (constants) isDarwin colors;
in
{
  options.apps.zsh = {
    enable = lib.mkEnableOption "Enable Zsh";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        completionInit = ''
          fpath+=("${pkgs.zsh-completions}/share/zsh/site-functions")
          autoload -U compinit && compinit -C
        '';
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        zsh-abbr.enable = true;

        history = {
          size = 100000;
          save = 100000;
          path = "$HOME/.zsh_history";
          append = true;
          share = true;
          extended = true;
          ignoreDups = true;
          ignoreAllDups = true;
          saveNoDups = true;
          findNoDups = true;
          ignoreSpace = true;
        };

        initContent = lib.mkBefore ''
          export LS_COLORS="di=1;36;40:ln=1;35;40:so=1;32;40:pi=1;33;40:ex=1;31;40:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${colors.fg2}"
          autoload -U up-line-or-beginning-search
          autoload -U down-line-or-beginning-search
          zle -N up-line-or-beginning-search
          zle -N down-line-or-beginning-search
          bindkey "^[[A" up-line-or-beginning-search
          bindkey "^[[B" down-line-or-beginning-search
          bindkey "^P" up-line-or-beginning-search
          bindkey "^N" down-line-or-beginning-search

          bindkey "^[[H" beginning-of-line
          bindkey "^[[F" end-of-line
          bindkey "^[[3~" delete-char
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word

          export PROMPT_COLOR="%F{${builtins.replaceStrings [ "#" ] [ "" ] colors.green}"

          zstyle ':completion:*' menu select
          zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
          zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
          zstyle ':completion:*' verbose true
          zstyle ':completion:*:descriptions' format '%B%d%b'
          zstyle ':completion:*:messages' format '%d'
          zstyle ':completion:*:warnings' format 'No matches for: %d'
          zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'

          setopt CORRECT
          setopt EXTENDED_GLOB
          unsetopt CASE_GLOB
          setopt AUTO_PUSHD
          setopt PUSHD_IGNORE_DUPS
          unsetopt BEEP
          setopt IGNORE_EOF
        '';

        defaultKeymap = "viins";

        sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less -R";
          LESS = "-R";
        };

        localVariables = {
          LANG = "en_US.UTF-8";
          LC_ALL = "en_US.UTF-8";
        };

        # Keep Homebrew setup out of .zshenv so non-interactive zsh commands do
        # not spawn Homebrew just to initialize their environment.
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
      };

      programs.fzf = {
        enable = true;
        enableZshIntegration = true;
      };
      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
      };
    };
  };
}
