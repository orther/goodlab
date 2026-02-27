{pkgs, ...}: {
  programs.fish = {
    enable = true;
    shellAliases = {
      ".." = "cd ..";
      cat = "bat --style=plain --theme=base16 --paging=never";
      neofetch = "fastfetch";
      sudo = "sudo";
      v = "vim";
    };
    interactiveShellInit = ''
      # Fortune greeting
      if command -q fortune
        fortune
      end

      # Homebrew PATH for Apple Silicon macOS
      if test (uname -m) = arm64; and test (uname -s) = Darwin
        eval (/opt/homebrew/bin/brew shellenv)
      end

      # Force Nix fzf even if Homebrew is earlier in PATH
      function fzf --wraps=fzf
        command ${pkgs.fzf}/bin/fzf $argv
      end
      function fzf-tmux --wraps=fzf-tmux
        command ${pkgs.fzf}/bin/fzf-tmux $argv
      end

      # Initialize mise
      if command -q mise
        mise activate fish | source
      end
    '';
  };
}
