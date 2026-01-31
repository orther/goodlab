{pkgs, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ".." = "cd ..";
      cat = "bat --style=plain --theme=base16 --paging=never ";
      neofetch = "fastfetch";
      sudo = "sudo ";
      v = "vim ";
    };
    # inspo: https://discourse.nixos.org/t/brew-not-on-path-on-m1-mac/26770/4
    initContent = ''
      command -v fortune >/dev/null 2>&1 && fortune

      if [[ $(uname -m) == 'arm64' ]] && [[ $(uname -s) == 'Darwin' ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Force Nix fzf even if Homebrew is earlier in PATH.
      fzf() { command ${pkgs.fzf}/bin/fzf "$@"; }
      fzf-tmux() { command ${pkgs.fzf}/bin/fzf-tmux "$@"; }

      # Initialize mise
      if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate zsh)"
      fi

      # Keep Ctrl-R bound to history search (or fzf) even if keymaps get reset.
      if (( $+widgets[fzf-history-widget] )); then
        for keymap in emacs viins; do
          bindkey -M "$keymap" '^R' fzf-history-widget
        done
      else
        for keymap in emacs viins; do
          bindkey -M "$keymap" '^R' history-incremental-search-backward
        done
      fi
    '';
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      # inspo: https://discourse.nixos.org/t/zsh-zplug-powerlevel10k-zshrc-is-readonly/30333/3
      {
        name = "powerlevel10k-config";
        src = ./_p10k;
        file = "p10k.zsh";
      }
    ];
  };
}
