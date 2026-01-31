# Tmux Quick Guide (Goodlab Config)

This is a **custom tmux configuration** managed via Nix and Home Manager. It
includes Catppuccin theming, vim-aware pane navigation, and a project-switching
workflow. If you're used to stock tmux, note that several defaults are changed.

---

## Ghostty Integration

Ghostty auto-starts tmux when you open a terminal:

```
zsh -lc 'tmux attach || tmux; exec zsh'
```

- Opening Ghostty attaches to an existing tmux session if one exists
- If no session exists, it creates a new one
- If you exit tmux (kill all windows), you drop to a plain zsh shell

---

## Prefix Key

> **Your prefix is `Ctrl+q`** (not the default `Ctrl+b`).

All prefixed commands: press `Ctrl+q`, release, then press the command key.

---

## Keybinding Reference

### Windows (tabs)

| Keybinding | Action |
|------------|--------|
| `prefix + c` | Create new window |
| `prefix + r` | Rename current window |
| `prefix + &` | Kill current window (with confirmation) |
| `prefix + n` | Next window |
| `prefix + p` | Previous window |
| `prefix + 1–9` | Jump to window by number (windows start at 1) |
| `prefix + w` | Interactive window/session picker |

### Panes (splits)

| Keybinding | Action |
|------------|--------|
| `prefix + v` | Vertical split (side-by-side), keeps current path |
| `prefix + s` | Horizontal split (top/bottom), keeps current path |
| `prefix + x` | Kill current pane (with confirmation) |
| `prefix + z` | Zoom/unzoom pane (fullscreen toggle) |
| `prefix + q` | Show pane numbers (press number to jump) |
| `prefix + o` | Cycle through panes |
| `Shift + ←/→/↑/↓` | Resize pane by 8 cells (no prefix) |

### Navigation (vim-aware)

| Keybinding | Action |
|------------|--------|
| `Ctrl + h` | Move left (pane or vim split) |
| `Ctrl + j` | Move down |
| `Ctrl + k` | Move up |
| `Ctrl + l` | Move right |

These work **without a prefix** and pass through to vim/neovim when a vim
process is detected (via `vim-tmux-navigator`).

### Copy Mode (vi bindings)

Enter with `prefix + [`. Navigate with vim keys.

| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `y` | Copy selection |
| `/` | Search forward |
| `?` | Search backward |
| `Ctrl + u/d` | Scroll half-page up/down |
| `q` or `Esc` | Exit copy mode |

Paste with `prefix + ]`.

### Utility

| Keybinding | Action |
|------------|--------|
| `prefix + ?` | Quick help popup (press any key to dismiss) |
| `prefix + R` | Reload tmux config |
| `prefix + C-l` | Send Ctrl+L (clear screen) to the pane |
| `Ctrl + f` | Project selector (no prefix, see below) |
| `prefix + d` | Detach from session |
| `prefix + :` | Command mode |

---

## Project Selector (`Ctrl+f`)

Press **`Ctrl+f`** (no prefix) to open a fuzzy project picker.

1. Scans directories under `~/code` (1–2 levels deep)
2. Uses `fd` for listing (falls back to `find`)
3. Opens `fzf` for fuzzy selection
4. Opens a new tmux window with a shell in the selected directory
5. Cancel with `Esc` to drop to a login shell

**Custom project root:**

```bash
export CODE_DIR=~/projects  # default is ~/code
```

---

## Vim Integration

`Ctrl+h/j/k/l` moves seamlessly between tmux panes and neovim splits. The
`vim-tmux-navigator` plugin is installed on both sides — tmux detects if a pane
is running vim/nvim/fzf and forwards keys accordingly.

No special keybindings to remember. It just works.

---

## Sessions

Sessions persist in the background when you detach.

```bash
tmux ls                      # List sessions
tmux new -s <name>           # New named session
tmux attach -t <name>        # Attach to session
tmux kill-session -t <name>  # Kill session
prefix + d                   # Detach (session keeps running)
prefix + $                   # Rename current session
```

**Note:** `prefix + s` is rebound to horizontal split in this config. Use
`prefix + w` for the interactive session/window picker instead.

---

## Common Workflows

### Starting a Coding Session

1. Open Ghostty → lands in tmux
2. `Ctrl+f` → pick a project
3. `nvim .` → open editor
4. `prefix + v` → side-by-side terminal for commands
5. `Ctrl+h/l` → hop between editor and terminal

### Multiple Projects

Use **windows** as project tabs:

- `prefix + c` → new window
- `Ctrl+f` → pick another project
- `prefix + 1/2/3` → jump between projects
- `prefix + r` → rename windows for clarity

Or use **sessions** for full isolation:

```bash
tmux new -s frontend     # first project
prefix + d               # detach
tmux new -s backend      # second project
tmux attach -t frontend  # jump back
```

### Detach and Reattach

```bash
prefix + d    # detach — everything keeps running
# close terminal, reboot Ghostty, SSH from another machine...
tmux attach   # right back where you left off
```

### Copy Output from Scrollback

1. `prefix + [` → enter copy mode
2. Navigate with vim keys (`k` to scroll up, `/term` to search)
3. `v` → start selection
4. `y` → copy
5. `prefix + ]` → paste

### Shared Sessions (Pair Programming)

```bash
# You:
tmux new -s pair

# Your pair (over SSH):
ssh you@host
tmux attach -t pair
```

Both see the same session in real-time.

---

## Hierarchy

```
Session (persists across disconnects)
  ├── Window 1 (tab)
  │     ├── Pane 1
  │     └── Pane 2
  ├── Window 2
  └── Window 3
```

- **Session** = workspace (e.g., "frontend", "ops")
- **Window** = task within a workspace (e.g., "editor", "logs")
- **Pane** = split within a window

---

## Theme

**Catppuccin Macchiato** — current window in peach, others in blue. Status bar
shows hostname and date/time on the right. Configured in
`modules/home-manager/tmux.nix`.

---

## Configuration

| Setting | Value |
|---------|-------|
| Base index | 1 (windows start at 1) |
| Scrollback | 10,000 lines |
| Key mode | vi |
| Mouse | enabled |
| Escape time | 10ms |
| Terminal | screen-256color |

**Config source:** `modules/home-manager/tmux.nix` (Nix-managed)

**Reload:** `prefix + R` after rebuilding, or deploy with `just deploy <host>`.

---

## Troubleshooting

### `Ctrl+b` doesn't work

This config uses `Ctrl+q`. Old muscle memory? It'll take a day to adjust.

### Mouse drag doesn't copy to clipboard

Hold `Shift` while selecting to bypass tmux and use terminal-native selection,
then `Cmd+C` (macOS). Or use copy mode (`prefix + [`) for tmux-internal copy.

### Pane navigation not working with vim

Ensure you're using the provided neovim config which includes
`vim-tmux-navigator`. The tmux side detects vim/nvim/fzf processes
automatically.

### Sessions don't survive reboot

Tmux sessions are in-memory. They survive terminal closes and detaches but not
reboots. Use `tmux-resurrect` (not currently configured) if you need persistence.

---

## Quick Reference Card

```
Prefix: Ctrl+q

prefix + c        new window
prefix + v        vertical split
prefix + s        horizontal split
prefix + 1–9      jump to window
prefix + r        rename window
prefix + d        detach
prefix + [        copy mode
prefix + ?        help popup
prefix + R        reload config

Ctrl + h/j/k/l    navigate panes & vim
Ctrl + f           project picker
Shift + arrows     resize panes
```
