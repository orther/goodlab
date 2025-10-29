{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;

    # Use tmux 3.4+ for latest features
    package = pkgs.tmux;

    # Set prefix to C-a (more ergonomic than default C-b)
    prefix = "C-a";

    # Enable mouse support for scrolling and pane selection
    mouse = true;

    # Use vi-style keybindings in copy mode
    keyMode = "vi";

    # Start window and pane numbering at 1 (0 is too far on keyboard)
    baseIndex = 1;

    # Renumber windows when one is closed
    # This keeps window numbers sequential
    escapeTime = 0;

    # Set default terminal to enable true color support
    terminal = "screen-256color";

    # Use zsh as default shell
    shell = "${pkgs.zsh}/bin/zsh";

    # Enable focus events (needed for vim/neovim autoread)
    focusEvents = true;

    # Set scrollback buffer size
    historyLimit = 50000;

    # Plugin configuration
    plugins = with pkgs.tmuxPlugins; [
      # Sensible defaults that everyone can agree on
      {
        plugin = sensible;
        extraConfig = ''
          # Additional sensible settings
          set -g display-time 4000
          set -g status-interval 5
        '';
      }

      # Seamless navigation between vim and tmux panes
      {
        plugin = vim-tmux-navigator;
        extraConfig = ''
          # Smart pane switching with awareness of vim splits
          # Uses C-h, C-j, C-k, C-l to navigate
          is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
              | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
          bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
          bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
          bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
          bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

          # Restore clear screen with prefix + C-l
          bind C-l send-keys 'C-l'
        '';
      }

      # Copy to system clipboard
      {
        plugin = yank;
        extraConfig = ''
          # Use vi-style copy mode keybindings
          set -g @yank_selection 'clipboard'
          set -g @yank_selection_mouse 'clipboard'

          # Copy mode vi bindings
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
          bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
        '';
      }

      # Session persistence - save and restore tmux sessions
      {
        plugin = resurrect;
        extraConfig = ''
          # Restore vim/neovim sessions
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'

          # Restore pane contents
          set -g @resurrect-capture-pane-contents 'on'

          # Restore additional programs
          set -g @resurrect-processes 'ssh psql mysql sqlite3 "~npm start" "~npm run dev" "~bun dev"'
        '';
      }

      # Automatic session saving and restoration
      {
        plugin = continuum;
        extraConfig = ''
          # Auto-save sessions every 15 minutes
          set -g @continuum-save-interval '15'

          # Auto-restore when tmux starts
          set -g @continuum-restore 'on'

          # Show save status in status bar (optional)
          set -g status-right 'Continuum: #{continuum_status}'
        '';
      }

      # Beautiful catppuccin theme (mocha variant - dark with pastel colors)
      {
        plugin = catppuccin;
        extraConfig = ''
          # Set theme flavor (latte, frappe, macchiato, mocha)
          set -g @catppuccin_flavour 'mocha'

          # Window status format
          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator " "
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"

          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#W"

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#W"

          # Status bar modules
          set -g @catppuccin_status_modules_right "directory session"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"

          # Directory module
          set -g @catppuccin_directory_text "#{pane_current_path}"
        '';
      }
    ];

    # Additional custom configuration
    extraConfig = ''
      # ============================================
      # Terminal and Color Settings
      # ============================================

      # Enable true color (24-bit) support
      set -ga terminal-overrides ",*256col*:Tc"
      set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
      set-environment -g COLORTERM "truecolor"

      # ============================================
      # Key Bindings
      # ============================================

      # Reload configuration file
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Better split window bindings
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window in current path
      bind c new-window -c "#{pane_current_path}"

      # Resize panes with vim-style keys (uppercase)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Quick pane selection with prefix + h/j/k/l
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Easy window navigation
      bind -r C-h select-window -t :-
      bind -r C-l select-window -t :+

      # Swap windows left/right
      bind -r "<" swap-window -d -t -1
      bind -r ">" swap-window -d -t +1

      # Toggle synchronize panes (send commands to all panes)
      bind S set-window-option synchronize-panes\; display "Synchronize panes: #{?pane_synchronized,ON,OFF}"

      # Break pane into new window
      bind b break-pane -d

      # ============================================
      # Copy Mode Settings
      # ============================================

      # Enter copy mode with prefix + [
      # In copy mode:
      #   v - begin selection
      #   C-v - rectangle selection
      #   y - copy and exit
      #   Escape - exit copy mode

      # Use v to trigger selection instead of Space
      bind -T copy-mode-vi v send -X begin-selection

      # Use y to yank current selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Use P to paste (since p is bound to previous window)
      bind P paste-buffer

      # Copy mode search
      bind -T copy-mode-vi / command-prompt -i -p "search down" "send -X search-forward-incremental \"%%%\""
      bind -T copy-mode-vi ? command-prompt -i -p "search up" "send -X search-backward-incremental \"%%%\""

      # ============================================
      # Mouse Support Settings
      # ============================================

      # Drag to select and copy text
      bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-and-cancel

      # Double click to select word
      bind -n DoubleClick1Pane select-pane \; copy-mode -M \; send -X select-word \; send -X copy-selection-and-cancel

      # Triple click to select line
      bind -n TripleClick1Pane select-pane \; copy-mode -M \; send -X select-line \; send -X copy-selection-and-cancel

      # ============================================
      # Window and Pane Settings
      # ============================================

      # Renumber windows sequentially after closing any of them
      set -g renumber-windows on

      # Start pane numbering at 1 instead of 0
      set -g pane-base-index 1

      # Automatically set window title
      set-window-option -g automatic-rename on
      set-option -g set-titles on

      # Monitor activity in other windows
      setw -g monitor-activity on
      set -g visual-activity off

      # ============================================
      # Status Bar Settings
      # ============================================

      # Update status bar every 5 seconds
      set -g status-interval 5

      # Status bar position
      set -g status-position bottom

      # Message display time (milliseconds)
      set -g display-time 2000

      # ============================================
      # Session Management
      # ============================================

      # Don't detach tmux when killing a session
      set -g detach-on-destroy off

      # Longer session history
      set -g history-limit 50000

      # ============================================
      # Additional Ergonomic Settings
      # ============================================

      # Allow multiple commands without pressing prefix again
      set -g repeat-time 600

      # Enable focus events for terminal applications
      set -g focus-events on

      # Aggressive resize (useful for grouped sessions)
      setw -g aggressive-resize on

      # Enable clipboard on macOS
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        set -g default-command "reattach-to-user-namespace -l ${pkgs.zsh}/bin/zsh"
      ''}
    '';
  };

  # Add reattach-to-user-namespace for macOS clipboard support
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    pkgs.reattach-to-user-namespace
  ];
}
