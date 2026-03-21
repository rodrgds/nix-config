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
    enable = lib.mkEnableOption "Enable Zsh shell with gruvbox theme and all goodies";
  };

  config = lib.mkIf cfg.enable {
    # Enable zsh at system level on NixOS
    programs.zsh.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        # Use zsh-abbr for fish-like abbreviations
        zsh-abbr.enable = true;

        # History configuration
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

        # Enable fzf integration if fzf is enabled
        initContent = lib.mkBefore ''
          # Gruvbox color scheme for zsh
          # Set LS_COLORS for gruvbox
          export LS_COLORS="di=1;36;40:ln=1;35;40:so=1;32;40:pi=1;33;40:ex=1;31;40:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"

          # Gruvbox colors for zsh-syntax-highlighting (if not using the default)
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${colors.fg2}"

          # Enable fzf keybindings if fzf is available
          if command -v fzf &> /dev/null; then
            source ${pkgs.fzf}/share/fzf/key-bindings.zsh
            source ${pkgs.fzf}/share/fzf/completion.zsh
          fi

          # Better history search with up/down arrows
          autoload -U up-line-or-beginning-search
          autoload -U down-line-or-beginning-search
          zle -N up-line-or-beginning-search
          zle -N down-line-or-beginning-search
          bindkey "^[[A" up-line-or-beginning-search
          bindkey "^[[B" down-line-or-beginning-search
          bindkey "^P" up-line-or-beginning-search
          bindkey "^N" down-line-or-beginning-search

          # Useful keybindings
          bindkey "^[[H" beginning-of-line
          bindkey "^[[F" end-of-line
          bindkey "^[[3~" delete-char
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word

          # Gruvbox prompt colors
          export PROMPT_COLOR="%F{${builtins.replaceStrings [ "#" ] [ "" ] colors.green}}"

          # Better completion settings
          zstyle ':completion:*' menu select
          zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
          zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
          zstyle ':completion:*' verbose true
          zstyle ':completion:*:descriptions' format '%B%d%b'
          zstyle ':completion:*:messages' format '%d'
          zstyle ':completion:*:warnings' format 'No matches for: %d'
          zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'

          # Auto-correct commands
          setopt CORRECT

          # Extended globbing
          setopt EXTENDED_GLOB

          # Case-insensitive globbing
          unsetopt CASE_GLOB

          # Pushd instead of cd
          setopt AUTO_PUSHD
          setopt PUSHD_IGNORE_DUPS

          # Disable beeping
          unsetopt BEEP

          # Don't exit on EOF (Ctrl+D), require exit or logout
          setopt IGNORE_EOF
        '';

        # Default keymap - viins for normal mode, vicmd for command mode, emacs for default
        defaultKeymap = "viins";

        # Session variables
        sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less -R";
          LESS = "-R";
        };

        # Local variables
        localVariables = {
          # Ensure proper locale
          LANG = "en_US.UTF-8";
          LC_ALL = "en_US.UTF-8";
        };

        # Plugins
        plugins = [
          {
            name = "zsh-autosuggestions";
            src = pkgs.zsh-autosuggestions;
            file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
          }
          {
            name = "zsh-syntax-highlighting";
            src = pkgs.zsh-syntax-highlighting;
            file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
          }
          {
            name = "zsh-completions";
            src = pkgs.zsh-completions;
            file = "share/zsh/site-functions";
          }
        ];

        # Extra environment setup (runs before .zshrc content)
        envExtra = lib.optionalString isDarwin ''
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
      };

      # Enable fzf zsh integration (if fzf is enabled elsewhere)
      programs.fzf = {
        enableZshIntegration = true;
      };

      # Enable zoxide zsh integration (if zoxide is used)
      programs.zoxide = {
        enableZshIntegration = true;
      };

      # Enable direnv zsh integration
      programs.direnv = {
        enableZshIntegration = true;
      };
    };
  };
}
