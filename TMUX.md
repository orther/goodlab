# Tmux Configuration Guide

This repository includes a modern, feature-rich tmux configuration optimized for both NixOS and macOS systems. The configuration emphasizes developer productivity, seamless Vim/Neovim integration, beautiful aesthetics, and session persistence.

## Quick Start

### Starting Tmux

```bash
# Start a new tmux session
tmux

# Start a named session
tmux new -s mysession

# Attach to an existing session
tmux attach -t mysession

# List all sessions
tmux ls

# Kill a session
tmux kill-session -t mysession
```

### Essential Keybindings Reference

The **prefix** key is `Ctrl+a` (denoted as `C-a` below). Press prefix, then the command key.

| Command | Action |
|---------|--------|
| `C-a ?` | Show all keybindings (help) |
| `C-a r` | Reload tmux configuration |
| `C-a d` | Detach from session |
| `C-a $` | Rename current session |
| `C-a ,` | Rename current window |

## Core Workflow Cheatsheet

### Window Management

Windows are like tabs in your terminal. Each window can contain multiple panes.

| Command | Action |
|---------|--------|
| `C-a c` | Create new window (in current directory) |
| `C-a n` | Next window |
| `C-a p` | Previous window |
| `C-a 0-9` | Switch to window by number |
| `C-a w` | List all windows (interactive) |
| `C-a &` | Kill current window |
| `C-a <` | Swap window with previous |
| `C-a >` | Swap window with next |
| `C-a C-h` | Select previous window |
| `C-a C-l` | Select next window |

### Pane Management

Panes are splits within a window, allowing you to see multiple terminals at once.

| Command | Action |
|---------|--------|
| `C-a \|` | Split pane horizontally (side-by-side) |
| `C-a -` | Split pane vertically (top-bottom) |
| `C-a x` | Kill current pane |
| `C-a z` | Toggle pane zoom (fullscreen) |
| `C-a Space` | Toggle between pane layouts |
| `C-a {` | Move pane left |
| `C-a }` | Move pane right |
| `C-a !` | Convert pane to window |
| `C-a b` | Break pane into new window |

### Seamless Navigation (Vim Integration)

**Navigate between tmux panes AND Vim splits** using the same keybindings:

| Command | Action |
|---------|--------|
| `C-h` | Move to left pane/split |
| `C-j` | Move to lower pane/split |
| `C-k` | Move to upper pane/split |
| `C-l` | Move to right pane/split |
| `C-a C-l` | Clear screen (since C-l is used for navigation) |

**Inside tmux only** (with prefix):

| Command | Action |
|---------|--------|
| `C-a h` | Select left pane |
| `C-a j` | Select lower pane |
| `C-a k` | Select upper pane |
| `C-a l` | Select right pane |

### Pane Resizing

| Command | Action |
|---------|--------|
| `C-a H` | Resize pane left (repeatable) |
| `C-a J` | Resize pane down (repeatable) |
| `C-a K` | Resize pane up (repeatable) |
| `C-a L` | Resize pane right (repeatable) |

Hold down the key after prefix to repeat the resize action.

### Copy Mode (Vim-style)

Copy mode allows you to scroll through terminal history and copy text.

| Command | Action |
|---------|--------|
| `C-a [` | Enter copy mode |
| `q` or `Escape` | Exit copy mode |
| `v` | Begin selection |
| `C-v` | Toggle rectangle selection |
| `y` | Copy selection and exit |
| `C-a P` | Paste copied text |
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next search result |
| `N` | Previous search result |

**In copy mode, use Vim motions:**
- `h`, `j`, `k`, `l` - navigate
- `w`, `b` - word forward/backward
- `0`, `$` - start/end of line
- `g`, `G` - top/bottom of history
- `C-u`, `C-d` - page up/down

### Mouse Support

Mouse is fully enabled! You can:

- **Click** to select panes
- **Drag** borders to resize panes
- **Scroll** to navigate history
- **Double-click** to select and copy a word
- **Triple-click** to select and copy a line
- **Right-click and drag** to select text, auto-copies on release

### Session Persistence

Sessions are automatically saved every 15 minutes and restored when tmux starts.

| Command | Action |
|---------|--------|
| `C-a C-s` | Manually save session |
| `C-a C-r` | Manually restore session |

Sessions persist across:
- System reboots
- Terminal crashes
- Accidental tmux exits

## Advanced Features

### Synchronize Panes

Send the same commands to all panes in a window simultaneously.

```
C-a S    # Toggle pane synchronization
```

Great for running commands on multiple servers at once.

### Custom Workflows

#### Development Workspace

Create a project workspace with three panes:

```bash
# Create new session for project
tmux new -s myproject

# Split into three panes
C-a |    # Split horizontally
C-a -    # Split bottom pane vertically

# Navigate and set up each pane
C-h      # Left pane: editor (vim/neovim)
C-l      # Right top: dev server
C-j      # Right bottom: git/commands
```

#### Multiple Server Management

```bash
# Create session with multiple windows
tmux new -s servers

# Create window for each server
C-a c    # Create new window
C-a ,    # Rename to "production"
# SSH into production server

C-a c    # Create another window
C-a ,    # Rename to "staging"
# SSH into staging server

# Navigate between servers
C-a 0-9  # Jump to window by number
C-a w    # List all windows
```

## Plugin Features

### Tmux Sensible

Automatically configures sensible defaults:
- Faster escape time (0ms instead of 500ms)
- Larger scrollback buffer (50,000 lines)
- Better status bar refresh rate
- Focus events enabled for Vim/Neovim

### Vim-Tmux Navigator

**Zero-friction navigation** between Vim splits and tmux panes:

```
C-h, C-j, C-k, C-l    # Navigate anywhere
```

Works in:
- Vim
- Neovim
- Any terminal application in tmux

### Tmux Yank

**Smart clipboard integration** across platforms:

- Automatically copies to system clipboard
- Works on Linux, macOS, and WSL
- Vi-mode keybindings in copy mode
- Mouse selection auto-copies

### Tmux Resurrect

**Save and restore complete tmux environment:**

Saves:
- All sessions, windows, and panes
- Pane layouts and sizes
- Working directories
- Running programs (including vim sessions!)
- Bash/zsh history

What gets restored:
- Vim/Neovim sessions (if you use sessions)
- SSH connections
- Development servers (npm, bun, etc.)
- Database clients (psql, mysql, sqlite3)

### Tmux Continuum

**Automatic session management:**

- Auto-saves every 15 minutes
- Auto-restores on tmux start
- Zero-effort session persistence
- Status indicator in status bar

### Catppuccin Theme

**Beautiful, modern aesthetics:**

- Mocha flavor (dark theme with pastel colors)
- Consistent with popular editor themes
- Easy on the eyes for long coding sessions
- Harmonizes with modern development tools

## Configuration Details

### Terminal Colors

- **True color support** (24-bit color)
- 256-color compatible
- Proper terminal type (`screen-256color`)
- Works with modern terminal emulators

### Default Settings

```
Prefix:           C-a (Ctrl+a)
Mouse:            Enabled
Copy mode:        Vi keybindings
Window start:     1 (not 0)
Pane start:       1 (not 0)
Shell:            zsh
Escape time:      0ms
History:          50,000 lines
Auto-rename:      On
Activity monitor: On
```

### Key Design Decisions

**Prefix: C-a instead of C-b**
- More ergonomic (home row)
- Muscle memory from GNU screen
- Less finger stretching

**Window/Pane numbering from 1**
- Number keys are left-to-right on keyboard
- 0 is far right, awkward for first window
- More intuitive for most users

**Vi mode everywhere**
- Consistent with Vim/Neovim workflow
- Familiar keybindings for navigation
- Efficient text selection and copy

**Mouse enabled by default**
- Lower barrier to entry
- Doesn't interfere with keyboard workflow
- Helpful for demonstrations and pairing

## Troubleshooting

### Colors not working correctly

Check your terminal emulator supports true color:

```bash
# Test true color support
awk 'BEGIN{
    s="/\\/\\/\\/\\/\\"; s=s s s s s s s s;
    for (colnum = 0; colnum<77; colnum++) {
        r = 255-(colnum*255/76);
        g = (colnum*510/76);
        b = (colnum*255/76);
        if (g>255) g = 510-g;
        printf "\033[48;2;%d;%d;%dm", r,g,b;
        printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
        printf "%s\033[0m", substr(s,colnum+1,1);
    }
    printf "\n";
}'
```

Should display a smooth color gradient.

**Fix:** Add to your shell profile:
```bash
export TERM=xterm-256color
```

### Vim/Neovim navigation not working

**Symptoms:** C-h, C-j, C-k, C-l don't switch between Vim and tmux.

**Fix:** Add to your Vim/Neovim config:

For Vim (`~/.vimrc`):
```vim
" Vim-tmux navigator
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> <C-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <C-j> :TmuxNavigateDown<cr>
nnoremap <silent> <C-k> :TmuxNavigateUp<cr>
nnoremap <silent> <C-l> :TmuxNavigateRight<cr>
```

For Neovim (with lazy.nvim):
```lua
{
  "christoomey/vim-tmux-navigator",
  lazy = false,
}
```

### Clipboard not working

**macOS:** Requires `reattach-to-user-namespace` (included in config)

**Linux:** Requires `xclip` or `xsel`:
```bash
# Install xclip
sudo apt install xclip  # Debian/Ubuntu
sudo dnf install xclip  # Fedora
```

**WSL:** Clipboard should work automatically with WSL2.

### Sessions not persisting

Check tmux-resurrect and tmux-continuum are loaded:

```bash
tmux show-environment -g | grep continuum
```

Should show `@continuum-restore=on`.

**Manual save/restore:**
```
C-a C-s    # Save
C-a C-r    # Restore
```

### Can't reload config

**Symptom:** `C-a r` doesn't reload configuration.

**Workaround:**
```bash
tmux source-file ~/.config/tmux/tmux.conf
```

On NixOS/nix-darwin, the config is managed by home-manager:
```bash
home-manager switch
```

## Integration with Other Tools

### Neovim/Vim Integration

This configuration is optimized for Neovim/Vim users:

1. **Seamless pane navigation** with vim-tmux-navigator
2. **Zero escape delay** for mode switching
3. **Focus events** for auto-reload (`:set autoread`)
4. **Session persistence** with resurrect
5. **Shared keybindings** for muscle memory

### FZF Integration

Combine tmux with fzf for powerful fuzzy finding:

```bash
# Switch tmux sessions with fzf
bind-key s split-window -v "tmux list-sessions | sed -E 's/:.*$//' | grep -v \"^$(tmux display-message -p '#S')\$\" | fzf --reverse | xargs tmux switch-client -t"
```

### Git Workflow

```bash
# Typical git workflow in tmux
C-a |     # Split pane
# Left: editor with changes
# Right: git commands

# In right pane:
git status
git diff
git add -p
git commit
```

### SSH Session Management

```bash
# Create session for each server
tmux new -s server1
ssh user@server1

# Detach and create another
C-a d
tmux new -s server2
ssh user@server2

# List all sessions
tmux ls

# Attach to specific session
tmux attach -t server1
```

## Customization

The configuration is managed by Nix in `modules/home-manager/tmux.nix`.

### Change theme flavor

Edit the catppuccin flavor (latte, frappe, macchiato, mocha):

```nix
set -g @catppuccin_flavour 'frappe'  # Change from mocha to frappe
```

### Adjust auto-save interval

Change from 15 minutes to another interval:

```nix
set -g @continuum-save-interval '30'  # Save every 30 minutes
```

### Disable mouse

If you prefer keyboard-only workflow:

```nix
mouse = false;  # In the main configuration
```

### Add custom keybindings

Add to the `extraConfig` section:

```nix
extraConfig = ''
  # Your custom keybindings here
  bind-key C-t display-message "Custom keybinding!"
'';
```

## Learning Resources

### Interactive Tutorial

Start tmux and press `C-a ?` to see all keybindings.

Practice these core commands:
1. `C-a c` - Create windows
2. `C-a |` and `C-a -` - Split panes
3. `C-h/j/k/l` - Navigate panes
4. `C-a [` - Copy mode (use vim motions)
5. `C-a z` - Zoom pane

### Recommended Practice Workflow

```bash
# Day 1: Basic navigation
tmux
C-a |    # Split horizontally
C-a -    # Split vertically
C-h/j/k/l   # Navigate around

# Day 2: Windows
C-a c    # Create multiple windows
C-a n/p  # Navigate windows
C-a ,    # Rename windows

# Day 3: Copy mode
C-a [    # Enter copy mode
v        # Select text
y        # Copy
C-a P    # Paste

# Day 4: Sessions
C-a d    # Detach
tmux ls  # List sessions
tmux attach  # Reattach

# Day 5: Advanced
C-a S    # Synchronize panes
C-a b    # Break pane to window
C-a z    # Zoom toggle
```

## Tips and Tricks

### Workflow Optimization

**Rename sessions immediately:**
```bash
tmux new -s project-name   # Not tmux, then C-a $
```

**Use session per project:**
```bash
tmux new -s website
tmux new -s api
tmux new -s database-admin
```

**Vertical splits for code, horizontal for logs:**
```bash
C-a |    # Code left, terminal right
C-a -    # Terminal split: top for commands, bottom for logs
```

### Power User Commands

**Show all tmux options:**
```
C-a :show-options -g
```

**Show all window options:**
```
C-a :show-window-options -g
```

**Kill all sessions except current:**
```bash
tmux kill-session -a
```

**Swap two panes:**
```
C-a {    # Swap with previous pane
C-a }    # Swap with next pane
```

**Move window between sessions:**
```bash
tmux move-window -s source-session:1 -t target-session:9
```

### Scripting Tmux

Create project workspace automatically:

```bash
#!/bin/bash
# setup-project.sh

SESSION="myproject"

# Create session
tmux new-session -d -s $SESSION -n "editor"

# Split window
tmux split-window -h -t $SESSION:1
tmux split-window -v -t $SESSION:1.2

# Run commands in each pane
tmux send-keys -t $SESSION:1.1 "nvim" C-m
tmux send-keys -t $SESSION:1.2 "npm run dev" C-m
tmux send-keys -t $SESSION:1.3 "git status" C-m

# Attach to session
tmux attach-t $SESSION
```

## Philosophy

This tmux configuration embodies several key principles:

1. **Ergonomics First:** Keybindings optimized for minimal finger movement
2. **Vim Integration:** Seamless workflow for Vim/Neovim users
3. **Visual Clarity:** Beautiful theme that's easy on the eyes
4. **Session Persistence:** Never lose your work environment
5. **Progressive Enhancement:** Mouse support for beginners, keyboard power for experts
6. **Declarative Configuration:** Managed by Nix for reproducibility

The goal is to create a tmux environment that feels natural, looks beautiful, and enhances productivity without getting in your way.

## Conclusion

Tmux transforms your terminal into a powerful IDE-like environment. With this configuration, you get:

- Professional aesthetics with Catppuccin theme
- Seamless Vim/Neovim integration
- Automatic session persistence
- Smart clipboard handling
- Ergonomic keybindings

**Start small:** Learn basic splits and windows first. Add more advanced features to your workflow as you become comfortable.

**Muscle memory:** The keybindings will feel awkward for a few days, then become second nature. Push through the initial learning curve.

**Customize:** This configuration is a starting point. Adjust it to match your workflow and preferences.

Happy tmuxing!
