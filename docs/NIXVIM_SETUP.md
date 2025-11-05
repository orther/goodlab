# Nixvim Configuration Guide

This document describes the nixvim setup configured across all your devices.

## Overview

nixvim is now installed on **all computers** (stud, mair, nblap, noir, zinc, vm) via the base home-manager module. It provides a fully-configured Neovim experience with modern development tools.

## What's Included

### Core Editor Features

- **Line numbers**: Relative and absolute
- **Smart indentation**: 2-space tabs, auto-indent
- **Search**: Smart case-sensitive search with highlighting
- **Persistent undo**: Undo history survives restarts
- **Split windows**: Sensible defaults (below/right)

### Colorscheme

- **Catppuccin Mocha** theme with integrated plugin support

### Essential Plugins

#### Navigation & File Management

- **Neo-tree** (`<leader>e`): File explorer
- **Telescope** (`<leader>ff/fg/fb/fh`): Fuzzy finder for files, grep, buffers, help
- **Which-key**: Shows available keybindings

#### Development Tools

- **LSP Servers** (auto-configured):
  - `nixd`: Nix language server with alejandra formatting
  - `ts_ls`: TypeScript/JavaScript
  - `pyright`: Python
  - `rust-analyzer`: Rust
  - `lua_ls`: Lua
  - `bashls`: Bash
  - `yamlls`, `jsonls`: YAML/JSON
  - `marksman`: Markdown

#### Code Intelligence

- **Treesitter**: Syntax highlighting and code understanding
- **nvim-cmp**: Autocompletion with LSP integration
- **Luasnip**: Snippet engine

#### Git Integration

- **Gitsigns**: Git status in sign column

#### Editor Enhancements

- **Comment.nvim**: Toggle comments with `gcc` (line) and `gbc` (block)
- **nvim-autopairs**: Auto-close brackets, quotes
- **nvim-surround**: Surround text objects
- **indent-blankline**: Visual indent guides
- **Lualine**: Status line with Catppuccin theme

## Key Bindings

### Leader Key

- **Space** is the leader key (`<leader>`)

### File Operations

- `<leader>w` - Save file
- `<leader>q` - Quit
- `<leader>bd` - Delete buffer

### Navigation

- `<leader>e` - Toggle file explorer (Neo-tree)
- `<leader>ff` - Find files (Telescope)
- `<leader>fg` - Live grep (Telescope)
- `<leader>fb` - Browse buffers (Telescope)
- `<leader>fh` - Search help tags (Telescope)
- `<leader>fr` - Recent files (Telescope)

### LSP Commands

- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementation
- `gr` - Find references
- `K` - Hover documentation
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code action
- `<leader>e` - Show diagnostics
- `[d` / `]d` - Previous/next diagnostic

### Window Management

- `<C-h/j/k/l>` - Navigate between splits
- `<C-Up/Down/Left/Right>` - Resize windows

### Editing

- `gcc` - Toggle line comment
- `gbc` - Toggle block comment
- `J/K` (visual mode) - Move lines up/down
- `</>` (visual mode) - Indent/outdent (keeps selection)

### Scrolling

- `<C-d>/<C-u>` - Scroll down/up (keeps cursor centered)
- `<Esc>` - Clear search highlighting

## Customization

The nixvim configuration is located at:

```
modules/home-manager/nixvim.nix
```

To customize:

1. **Edit the module**:

   ```nix
   # Add a new plugin
   plugins.new-plugin.enable = true;

   # Add a keybinding
   keymaps = [
     {
       mode = "n";
       key = "<leader>x";
       action = "<cmd>SomeCommand<cr>";
       options.desc = "Description";
     }
   ];
   ```

2. **Apply changes**:

   ```bash
   # On macOS (stud, mair, nblap)
   just deploy <hostname>

   # On NixOS (noir, zinc)
   just deploy <hostname>
   ```

## Deployment Status

Nixvim is configured in `modules/home-manager/base.nix`, which means it's automatically available on:

- ✅ **stud** (macOS Apple Silicon - personal)
- ✅ **mair** (macOS Intel - personal)
- ✅ **nblap** (macOS Apple Silicon - work)
- ✅ **noir** (NixOS x86_64 - homelab)
- ✅ **zinc** (NixOS x86_64 - homelab)
- ✅ **vm** (NixOS aarch64 - test VM)

## First Time Usage

After deploying, simply run:

```bash
nvim
```

The configuration will be automatically loaded with all plugins and LSP servers.

### Checking LSP Status

- Open a file (e.g., `nvim flake.nix`)
- Type `:LspInfo` to see active language servers
- Type `:checkhealth` to verify plugin health

## Troubleshooting

### LSP not working

1. Ensure the language server is enabled in `nixvim.nix`
2. Check `:LspInfo` for errors
3. Run `:checkhealth` to verify dependencies

### Plugin not loading

1. Check `nix flake check` for configuration errors
2. Verify the plugin is enabled in `nixvim.nix`
3. Redeploy with `just deploy <hostname>`

### Keybinding conflicts

- Use `<leader>?` (Which-key) to see all available bindings
- Check `keymaps` section in `nixvim.nix` for conflicts

## Performance

- Fast startup time: "Everything disabled by default" philosophy
- Generates optimized Lua configuration
- Uses native Neovim LSP (faster than CoC/ALE)
- Lazy-loads plugins when needed

## Resources

- **nixvim Docs**: https://nix-community.github.io/nixvim
- **nixvim GitHub**: https://github.com/nix-community/nixvim
- **nixvim Options Search**: https://nix-community.github.io/nixvim/search

---

**Configured**: 2025-10-14
**Maintained by**: goodlab homelab configuration
