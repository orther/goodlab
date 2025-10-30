# Neovim Configuration Guide

This document covers the Neovim setup configured via Nixvim in this repository. The configuration provides a modern, feature-rich development environment with LSP support, Treesitter syntax highlighting, and seamless tmux integration.

## Quick Start

### First Launch

```bash
# Neovim is available as:
nvim          # Main command
vim           # Alias to nvim
vi            # Alias to nvim

# Open a file
nvim file.nix

# Open with file explorer
nvim .
```

### Leader Key

The leader key is `Space`. Most custom commands start with `<leader>` (shown as `<Space>` in this guide).

### Most Important Commands (First 5 Minutes)

| Command | Description |
|---------|-------------|
| `<Space>e` | Toggle file explorer |
| `<Space>ff` | Find files (fuzzy search) |
| `<Space>fg` | Search in files (live grep) |
| `<Space>w` | Save file |
| `<Space>q` | Quit |
| `K` | Show documentation (LSP hover) |
| `gd` | Go to definition |
| `:q` | Quit |
| `:wq` | Save and quit |

## Essential Keyboard Commands

### Navigation

#### Basic Movement
- `h, j, k, l` - Left, Down, Up, Right
- `w` - Next word
- `b` - Previous word
- `0` - Start of line
- `$` - End of line
- `gg` - Top of file
- `G` - Bottom of file
- `<number>G` - Go to line number (e.g., `42G`)
- `Ctrl-d` - Half page down
- `Ctrl-u` - Half page up

#### Window Navigation (Tmux-Aware)
- `Ctrl-h` - Navigate left (works across tmux panes)
- `Ctrl-j` - Navigate down (works across tmux panes)
- `Ctrl-k` - Navigate up (works across tmux panes)
- `Ctrl-l` - Navigate right (works across tmux panes)

#### Window Resizing
- `Ctrl-Up` - Increase window height
- `Ctrl-Down` - Decrease window height
- `Ctrl-Left` - Decrease window width
- `Ctrl-Right` - Increase window width

#### Buffer Navigation
- `Shift-h` - Previous buffer
- `Shift-l` - Next buffer
- `<Space>bd` - Delete/close current buffer
- `<Space>fb` - List and search buffers

### File Operations

#### File Explorer (Neo-tree)
- `<Space>e` - Toggle file explorer
- `Space` (in tree) - Toggle folder/expand
- `Enter` - Open file
- `S` - Open in horizontal split
- `s` - Open in vertical split
- `a` - Create new file/directory
- `d` - Delete file/directory
- `r` - Rename file/directory
- `?` - Show help

#### Fuzzy Finding (Telescope)
- `<Space>ff` - Find files
- `<Space>fg` - Live grep (search in files)
- `<Space>fb` - Browse buffers
- `<Space>fh` - Help tags
- `<Space>fr` - Recent files
- `<Space>fc` - Commands

**In Telescope:**
- `Ctrl-j/k` or arrow keys - Navigate results
- `Enter` - Select
- `Ctrl-x` - Open in horizontal split
- `Ctrl-v` - Open in vertical split
- `Esc` - Close

### Editing

#### Modes
- `i` - Insert mode (before cursor)
- `a` - Insert mode (after cursor)
- `I` - Insert at start of line
- `A` - Insert at end of line
- `o` - New line below
- `O` - New line above
- `v` - Visual mode (character selection)
- `V` - Visual line mode
- `Ctrl-v` - Visual block mode
- `Esc` - Return to normal mode

#### Basic Editing
- `x` - Delete character
- `dd` - Delete line
- `yy` - Yank (copy) line
- `p` - Paste after cursor
- `P` - Paste before cursor
- `u` - Undo
- `Ctrl-r` - Redo
- `.` - Repeat last command

#### Advanced Editing
- `ciw` - Change inner word
- `ci"` - Change inside quotes
- `di(` - Delete inside parentheses
- `vi{` - Select inside braces
- `Alt-j` - Move line down
- `Alt-k` - Move line up
- `>` (visual mode) - Indent right
- `<` (visual mode) - Indent left

#### Comments
- `gcc` - Toggle comment on current line
- `gc` (visual mode) - Toggle comment on selection
- `gbc` - Toggle block comment

#### Surround Operations
- `ys<motion><char>` - Add surrounding (e.g., `ysiw"` wraps word in quotes)
- `ds<char>` - Delete surrounding (e.g., `ds"` removes quotes)
- `cs<char><char>` - Change surrounding (e.g., `cs"'` changes " to ')

### LSP Features

#### Navigation
- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementation
- `gr` - Show references
- `<Space>D` - Go to type definition

#### Information
- `K` - Hover documentation
- `Ctrl-k` - Signature help

#### Code Actions
- `<Space>rn` - Rename symbol
- `<Space>ca` - Code actions
- `<Space>f` - Format document

#### Diagnostics (Errors/Warnings)
- `[d` - Previous diagnostic
- `]d` - Next diagnostic
- `<Space>e` - Show diagnostic in floating window
- `<Space>q` - Add diagnostics to location list

#### Workspace
- `<Space>wa` - Add workspace folder
- `<Space>wr` - Remove workspace folder

### Git Integration

#### Fugitive
- `<Space>gs` - Git status
- `<Space>gc` - Git commit
- `<Space>gp` - Git push
- `<Space>gl` - Git log

#### Gitsigns (in buffer)
- Inline blame shows automatically after 300ms
- `]c` - Next hunk
- `[c` - Previous hunk
- `<Space>hp` - Preview hunk
- `<Space>hs` - Stage hunk
- `<Space>hr` - Reset hunk

### Terminal

- `Ctrl-\` - Toggle integrated terminal
- `Ctrl-\ Ctrl-\` - Enter terminal mode
- (In terminal) `Ctrl-\ Ctrl-n` - Exit terminal mode

### Search and Replace

#### Search
- `/pattern` - Search forward
- `?pattern` - Search backward
- `n` - Next match
- `N` - Previous match
- `*` - Search word under cursor
- `Esc` - Clear search highlights

#### Replace
- `:%s/old/new/g` - Replace all in file
- `:%s/old/new/gc` - Replace all with confirmation
- `:s/old/new/g` - Replace in current line
- (Visual mode) `:s/old/new/g` - Replace in selection

### Completion

While typing in insert mode:
- `Ctrl-Space` - Trigger completion manually
- `Tab` - Next completion item
- `Shift-Tab` - Previous completion item
- `Enter` - Confirm selection
- `Ctrl-e` - Close completion menu
- `Ctrl-d` - Scroll docs down
- `Ctrl-f` - Scroll docs up

## Language Support

### Supported Languages with LSP

The following languages have full LSP support (autocomplete, diagnostics, go-to-definition, etc.):

| Language | LSP Server | Treesitter | Notes |
|----------|-----------|------------|-------|
| TypeScript/TSX | ts_ls | ✅ | JavaScript included |
| JavaScript | ts_ls | ✅ | |
| Elixir | elixir-ls | ✅ | Phoenix (heex) included |
| Nix | nil | ✅ | Formatted with alejandra |
| Bash/Zsh | bash-language-server | ✅ | |
| YAML | yaml-language-server | ✅ | Kubernetes schemas |
| Docker | dockerls | ✅ | |
| Docker Compose | docker-compose-ls | ✅ | |
| Lua | lua-ls | ✅ | For Neovim config |
| Markdown | marksman | ✅ | |
| JSON | jsonls | ✅ | |
| GraphQL | - | ✅ | Syntax only (no LSP) |
| HTML | - | ✅ | Syntax only |
| CSS | - | ✅ | Syntax only |
| Go | - | ✅ | Add gopls for LSP |
| Python | - | ✅ | Add pyright for LSP |
| Rust | - | ✅ | Add rust-analyzer for LSP |

### Adding GraphQL LSP

GraphQL LSP server is not in nixpkgs. For projects needing it:

1. Add to project's `flake.nix` or use direnv
2. Ensure `graphql` package is in project dependencies
3. Create `.graphqlrc` config file in project root

## Tmux Integration

### Seamless Navigation

The configuration includes `vim-tmux-navigator` for unified navigation between Neovim splits and tmux panes:

- `Ctrl-h/j/k/l` - Navigate between Neovim windows AND tmux panes
- No distinction between Neovim splits and tmux panes when navigating

### Tmux Configuration Requirements

Add to your tmux configuration (`~/.tmux.conf` or via Nix):

```tmux
# Smart pane switching with awareness of Vim splits
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-l' select-pane -R

# Enable true color
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
```

### Clipboard Integration

The configuration automatically handles clipboard integration with tmux:
- Yanking in Neovim copies to system clipboard
- Works with tmux buffers automatically
- Use `"+y` to explicitly yank to system clipboard
- Use `"+p` to paste from system clipboard

### True Color Support

True colors are enabled automatically when running inside tmux, ensuring consistent colors between standalone and tmux sessions.

## Customization

### Setting as Default Editor

To make Neovim your default editor, edit `modules/home-manager/neovim.nix`:

```nix
programs.nixvim = {
  enable = true;
  defaultEditor = true;  # Uncomment or set to true
  # ...
}
```

Then rebuild your configuration:
```bash
just deploy $(hostname)
```

### Adding Language Servers

To add a new LSP server (e.g., Python's pyright):

1. Edit `modules/home-manager/neovim.nix`
2. Add to `plugins.lsp.servers`:

```nix
pyright = {
  enable = true;
};
```

3. Add corresponding Treesitter grammar to `grammarPackages`:

```nix
python
```

4. Rebuild configuration

### Adding Plugins

To add new plugins, add them to the `plugins` section in `neovim.nix`:

```nix
plugins.plugin-name = {
  enable = true;
  # plugin-specific settings
};
```

See [Nixvim plugins documentation](https://nix-community.github.io/nixvim/plugins/) for available plugins.

### Custom Keybindings

Add custom keymaps to the `keymaps` list in `neovim.nix`:

```nix
{
  mode = "n";  # normal mode
  key = "<leader>x";
  action = "<cmd>SomeCommand<cr>";
  options.desc = "Description for which-key";
}
```

### Color Scheme

Change the colorscheme in `neovim.nix`:

```nix
colorschemes.catppuccin = {
  enable = true;
  settings = {
    flavour = "mocha";  # mocha, macchiato, frappe, latte
    # ...
  };
};
```

Or use a different scheme entirely:
- `colorschemes.tokyonight`
- `colorschemes.gruvbox`
- `colorschemes.kanagawa`
- See nixvim docs for more options

## Configuration Files

### Location
Configuration is managed through Nix at:
- `modules/home-manager/neovim.nix` - Main configuration
- Generated config: `~/.config/nvim/` (managed by Nix, don't edit directly)

### Making Changes

1. Edit `modules/home-manager/neovim.nix`
2. Test: `nix flake check`
3. Deploy: `just deploy $(hostname)`
4. Changes take effect on next Neovim launch

### Configuration Structure

```nix
programs.nixvim = {
  enable = true;
  opts = { ... };              # Neovim options (set)
  globals = { ... };           # Global variables (let)
  colorschemes = { ... };      # Color scheme
  plugins = { ... };           # Plugin configuration
  keymaps = [ ... ];           # Keybindings
  extraConfigLua = "...";      # Raw Lua code
};
```

## Workflows

### Typical Development Session

```bash
# Start tmux session
tmux new -s dev

# Open project
cd ~/project
nvim .

# In Neovim:
# <Space>e - Open file explorer
# <Space>ff - Find files quickly
# Navigate with Ctrl-h/j/k/l (works across tmux panes)

# Split windows
# :split or :vsplit

# Open integrated terminal
# Ctrl-\

# Git workflow
# <Space>gs - Check status
# Stage changes in fugitive
# <Space>gc - Commit
```

### Multiple Files Workflow

```bash
# Open multiple files
nvim file1.ts file2.ts file3.ts

# Navigate between buffers
# Shift-h / Shift-l

# Or use buffer list
# <Space>fb

# Split to see two files
# :vsplit
# <Space>fb to open another file in split
```

### Debugging LSP Issues

```bash
# Check LSP status
:LspInfo

# Check installed servers
:Mason

# Restart LSP
:LspRestart

# View LSP logs
:LspLog

# Check diagnostics
:lua vim.diagnostic.open_float()
```

### Project-Specific Configuration

Use `direnv` and project-specific flakes:

```nix
# project/.envrc
use flake

# project/flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }: {
    devShells.default = nixpkgs.lib.mkShell {
      packages = with nixpkgs; [
        # Project-specific tools
        nodejs
        python3
      ];
    };
  };
}
```

Neovim will pick up tools from the dev shell automatically.

## Troubleshooting

### LSP Not Working

**Check if server is installed:**
```vim
:LspInfo
```

**Common issues:**
- LSP server needs to be enabled in `neovim.nix`
- Project-specific configuration may be needed (e.g., `tsconfig.json` for TypeScript)
- Some servers require workspace setup (`:LspStart`)

### Treesitter Highlighting Not Working

**Check parser installation:**
```vim
:TSInstallInfo
```

**Fix:**
All parsers are installed via Nix, so they should always work. If issues persist:
```bash
nix flake check  # Verify configuration
just deploy $(hostname)  # Rebuild
```

### Clipboard Not Working in Tmux

**Symptoms:** Yanking in Neovim doesn't copy to system clipboard

**Fix:**
1. Ensure tmux has `set -g set-clipboard on`
2. Check that `xclip` (Linux) or `pbcopy` (macOS) is available
3. Try explicit system clipboard: `"+y` instead of `y`

### Slow Performance

**Treesitter:**
Treesitter syntax highlighting can be slow on very large files. Disable temporarily:
```vim
:TSDisable highlight
```

**LSP:**
Some LSP servers are slow on large projects. Check:
```vim
:LspInfo  " See active clients
:LspStop  " Stop all clients
```

### Colors Look Wrong in Tmux

**Fix in tmux config:**
```tmux
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
```

**Or in shell:**
```bash
export TERM=tmux-256color
```

### Keybinding Conflicts

If a keybinding doesn't work:
1. Check for conflicts: `:map <key>`
2. See which-key help: `<Space>` (wait for popup)
3. Plugin-specific help: `:help plugin-name`

### Navigation Not Working Across Tmux Panes

Ensure tmux has the vim-tmux-navigator configuration (see Tmux Integration section above).

Test in terminal:
```bash
# Should show vim-related processes
ps -o state= -o comm= -t $(tty) | grep vim
```

## Advanced Features

### Macros

Record and replay command sequences:
- `qa` - Start recording macro into register 'a'
- (perform actions)
- `q` - Stop recording
- `@a` - Replay macro from register 'a'
- `@@` - Replay last macro

### Marks

Jump to specific locations:
- `ma` - Set mark 'a' at cursor
- `'a` - Jump to mark 'a'
- `''` - Jump back to previous position
- `:marks` - List all marks

### Registers

View and use registers:
- `:registers` - Show all registers
- `"ay` - Yank into register 'a'
- `"ap` - Paste from register 'a'
- `"0` - Last yank
- `"+` - System clipboard
- `"*` - Selection clipboard

### Folding

Code folding with Treesitter:
- `za` - Toggle fold under cursor
- `zA` - Toggle fold recursively
- `zc` - Close fold
- `zo` - Open fold
- `zM` - Close all folds
- `zR` - Open all folds

### Sessions

Save and restore editing sessions:
```vim
:mksession ~/session.vim
:source ~/session.vim
```

### Window Management

- `:split` - Horizontal split
- `:vsplit` - Vertical split
- `:only` - Close all other windows
- `Ctrl-w =` - Equalize window sizes
- `Ctrl-w T` - Move window to new tab
- `Ctrl-w r` - Rotate windows

## Performance Tips

1. **Disable features for large files:**
   ```vim
   :set syntax=off
   :TSDisable highlight
   ```

2. **Lazy load plugins:** (already configured in nixvim)

3. **Use ripgrep for searching:** (already configured with Telescope)

4. **Limit LSP features on large codebases:**
   ```vim
   :LspStop
   ```

## Resources

### Documentation
- `:help` - Neovim help
- `:help lsp` - LSP documentation
- `:Telescope help_tags` - Searchable help
- `:help vim-tmux-navigator` - Tmux integration help

### External Resources
- [Nixvim Documentation](https://nix-community.github.io/nixvim/)
- [Neovim Documentation](https://neovim.io/doc/)
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator)
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

### Learning Vim
- `vimtutor` - Interactive Vim tutorial (30 minutes)
- `:Tutor` - Neovim built-in tutorial
- [Vim Adventures](https://vim-adventures.com/) - Game for learning Vim

## Quick Reference Card

```
ESSENTIAL SHORTCUTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Navigation        | Files              | LSP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ctrl-hjkl  Move   | Space+e  Tree      | gd        Definition
Shift-hl   Buffers| Space+ff Files     | gr        References
gg/G       Top/Bot| Space+fg Grep      | K         Hover
Ctrl-d/u   Pg Dn/Up| Space+fb Buffers  | Space+rn  Rename
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Editing           | Visual             | Git
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
i/a        Insert | v        Select    | Space+gs  Status
dd         Del Ln | V        Line      | Space+gc  Commit
yy         Copy   | Ctrl-v   Block     | Space+gp  Push
p          Paste  | >/<      Indent    | ]c/[c     Next/Prev
u          Undo   | gc       Comment   |
Ctrl-r     Redo   | gq       Format    |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Summary

This Neovim configuration provides:

- ✅ Modern LSP-based development environment
- ✅ Treesitter syntax highlighting
- ✅ Seamless tmux integration
- ✅ Fuzzy finding and file navigation
- ✅ Git integration
- ✅ Reproducible via Nix
- ✅ Works on both macOS and NixOS
- ✅ Extensible and maintainable

The configuration prioritizes developer productivity while maintaining the reproducibility and declarative nature of Nix. All changes are version-controlled and can be deployed consistently across machines.

