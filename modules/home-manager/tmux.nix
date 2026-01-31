{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "cd-to-project" ''
      set -u
      set -o pipefail

      root="$HOME/code"
      if [ -n "''${CODE_DIR:-}" ]; then
        root="$CODE_DIR"
      fi
      if [ ! -d "$root" ]; then
        echo "cd-to-project: missing directory: $root" >&2
        exec "''${SHELL:-${pkgs.zsh}/bin/zsh}"
      fi

      if command -v fd >/dev/null 2>&1; then
        dirs="$(fd -t d -d 2 . "$root")"
      else
        dirs="$(find "$root" -mindepth 1 -maxdepth 2 -type d)"
      fi

      if ! command -v fzf >/dev/null 2>&1; then
        echo "cd-to-project: fzf not found on PATH" >&2
        exec "${pkgs.zsh}/bin/zsh" -l
      fi

      selected="$(printf '%s\n' "$dirs" | sed "s|^$root/||" | fzf --prompt='Project> ' --height=40% --layout=reverse --border)"
      status=$?
      if [ $status -ne 0 ] || [ -z "${selected:-}" ]; then
        exec "${pkgs.zsh}/bin/zsh" -l
      fi

      cd "$root/$selected"
      exec "${pkgs.zsh}/bin/zsh" -l
    '')
  ];

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 10000;
    keyMode = "vi";
    mouse = true;
    sensibleOnTop = false;
    terminal = "tmux-256color";

    extraConfig = ''
      # Set the prefix to `ctrl + q` instead of `ctrl + b`
      set -g prefix C-q
      unbind C-b

      # Use | and - to split a window vertically and horizontally instead of " and % respectively
      unbind '"'
      unbind %
      bind v split-window -h -c "#{pane_current_path}"
      bind s split-window -v -c "#{pane_current_path}"

      # Bind Arrow keys to resize the window
      bind -n S-Down resize-pane -D 8
      bind -n S-Up resize-pane -U 8
      bind -n S-Left resize-pane -L 8
      bind -n S-Right resize-pane -R 8

      # Rename window with prefix + r
      bind r command-prompt -I "#W" "rename-window '%%'"

      # Reload tmux config by pressing prefix + R
      bind R source-file ~/.config/tmux/tmux.conf \; display "TMUX Conf Reloaded"

      # Quick help popup (prefix + ?)
      bind ? display-popup -E "cat <<'EOF'
TMUX Quick Help

Prefix: Ctrl+q

Windows
  c   New window
  &   Close window
  r   Rename window
  n/p Next/Prev window
  0-9 Switch to window

Splits
  v   Split vertical
  s   Split horizontal
  h/j/k/l Move between panes
  Shift+Arrows Resize panes

Copy mode
  [   Enter copy mode
  Space Start selection
  Enter Copy
  q   Quit copy mode

Other
  R   Reload config
  l   Clear screen
  Ctrl+f Project selector
EOF
read -n 1 -s -r"

      # Clear screen with prefix + l
      bind C-l send-keys 'C-l'

      # Open a project in a separate window
      bind-key -n C-f run-shell "tmux new-window -n project-selector -c '$HOME/code' ${pkgs.zsh}/bin/zsh -lc 'cd-to-project'"

      # Apply Tc
      set -ga terminal-overrides ",xterm-256color:RGB:smcup@:rmcup@"
      set -ga terminal-overrides ",xterm-ghostty:RGB:smcup@:rmcup@"
      set -ga terminal-features ",xterm-256color:hyperlinks"
      set -ga terminal-features ",xterm-ghostty:hyperlinks"

      # Enable focus-events
      set -g focus-events on

      # Allow passthrough for OSC sequences (clickable hyperlinks, etc.)
      set -g allow-passthrough on

      # Smart pane switching with awareness of Vim splits
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf|atuin)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
    '';
  };

  catppuccin = {
    tmux = {
      enable = true;
      extraConfig = ''
        set -g @catppuccin_flavor "macchiato"
        set -g @catppuccin_status_background "none"

        set -g @catppuccin_window_current_number_color "#{@thm_peach}"
        set -g @catppuccin_window_current_text " #W"
        set -g @catppuccin_window_current_text_color "#{@thm_bg}"
        set -g @catppuccin_window_number_color "#{@thm_blue}"
        set -g @catppuccin_window_text " #W"
        set -g @catppuccin_window_text_color "#{@thm_surface_0}"
        set -g @catppuccin_status_left_separator "█"

        set -g status-right "#{E:@catppuccin_status_host}#{E:@catppuccin_status_date_time}"
        set -g status-left ""
      '';
    };
  };
}
