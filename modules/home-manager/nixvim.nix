{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
  ];
  programs.nixvim = {
    enable = true;

    # Use system clipboard (wl-copy only on Linux/Wayland)
    clipboard.providers.wl-copy.enable = pkgs.stdenv.isLinux;

    # Global settings
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # Editor options
    opts = {
      # Line numbers
      number = true;
      relativenumber = true;

      # Tabs and indentation
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      autoindent = true;
      smartindent = true;

      # Search
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      incsearch = true;

      # Appearance
      termguicolors = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 8;
      wrap = false;

      # Behavior
      swapfile = false;
      backup = false;
      undofile = true;
      updatetime = 250;
      timeoutlen = 300;

      # Split windows
      splitbelow = true;
      splitright = true;

      # Completion
      completeopt = ["menu" "menuone" "noselect"];
    };

    # Colorscheme
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha"; # mocha, macchiato, frappe, latte
        transparent_background = false;
        integrations = {
          cmp = true;
          gitsigns = true;
          treesitter = true;
          telescope.enabled = true;
          native_lsp.enabled = true;
        };
      };
    };

    # Core plugins
    plugins = {
      # Status line
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "catppuccin";
            component_separators = {
              left = "|";
              right = "|";
            };
            section_separators = {
              left = "";
              right = "";
            };
          };
        };
      };

      # File explorer
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          window = {
            width = 30;
            auto_expand_width = false;
          };
        };
      };

      # Fuzzy finder
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fr" = "oldfiles";
        };
        settings = {
          defaults = {
            layout_config = {
              horizontal = {
                prompt_position = "top";
              };
            };
            sorting_strategy = "ascending";
          };
        };
      };

      # Treesitter for syntax highlighting
      treesitter = {
        enable = true;
        nixGrammars = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # LSP
      lsp = {
        enable = true;
        keymaps = {
          diagnostic = {
            "<leader>e" = "open_float";
            "[d" = "goto_prev";
            "]d" = "goto_next";
          };
          lspBuf = {
            "gd" = "definition";
            "gD" = "declaration";
            "gi" = "implementation";
            "gr" = "references";
            "K" = "hover";
            "<leader>rn" = "rename";
            "<leader>ca" = "code_action";
          };
        };
        servers = {
          # Nix
          nixd = {
            enable = true;
            settings = {
              formatting.command = ["alejandra"];
            };
          };

          # TypeScript/JavaScript
          ts_ls.enable = true;

          # Python
          pyright.enable = true;

          # Rust
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };

          # Lua
          lua_ls.enable = true;

          # Bash
          bashls.enable = true;

          # YAML
          yamlls.enable = true;

          # JSON
          jsonls.enable = true;

          # Markdown
          marksman.enable = true;
        };
      };

      # Autocompletion
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-d>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-e>" = "cmp.mapping.close()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
          };
          sources = [
            {name = "nvim_lsp";}
            {name = "path";}
            {name = "buffer";}
          ];
        };
      };

      # Snippet engine (required for cmp)
      luasnip.enable = true;

      # Git integration
      gitsigns = {
        enable = true;
        settings = {
          current_line_blame = false;
          signs = {
            add.text = "│";
            change.text = "│";
            delete.text = "_";
            topdelete.text = "‾";
            changedelete.text = "~";
            untracked.text = "┆";
          };
        };
      };

      # Comment toggling
      comment = {
        enable = true;
        settings = {
          toggler = {
            line = "gcc";
            block = "gbc";
          };
          opleader = {
            line = "gc";
            block = "gb";
          };
        };
      };

      # Auto pairs
      nvim-autopairs.enable = true;

      # Indent guides
      indent-blankline = {
        enable = true;
        settings = {
          scope.enabled = true;
        };
      };

      # Which-key for key binding help
      which-key = {
        enable = true;
        settings = {
          delay = 500;
          icons.mappings = false;
          spec = [
            {
              __unkeyed-1 = "<leader>f";
              group = "Find";
            }
            {
              __unkeyed-1 = "<leader>c";
              group = "Code";
            }
            {
              __unkeyed-1 = "<leader>r";
              group = "Rename";
            }
          ];
        };
      };

      # Better buffer deletion
      bufdelete.enable = true;

      # Surrounding text objects
      nvim-surround.enable = true;

      # Web devicons
      web-devicons.enable = true;
    };

    # Key mappings
    keymaps = [
      # General
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options = {
          desc = "Save file";
        };
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options = {
          desc = "Quit";
        };
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>Bdelete<cr>";
        options = {
          desc = "Delete buffer";
        };
      }

      # File explorer
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options = {
          desc = "Toggle file explorer";
        };
      }

      # Clear search highlighting
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
      }

      # Better window navigation
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options = {
          desc = "Go to left window";
        };
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options = {
          desc = "Go to lower window";
        };
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options = {
          desc = "Go to upper window";
        };
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options = {
          desc = "Go to right window";
        };
      }

      # Resize windows
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<cr>";
        options = {
          desc = "Increase window height";
        };
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<cr>";
        options = {
          desc = "Decrease window height";
        };
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<cr>";
        options = {
          desc = "Decrease window width";
        };
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<cr>";
        options = {
          desc = "Increase window width";
        };
      }

      # Move lines up/down
      {
        mode = "v";
        key = "J";
        action = ":m '>+1<cr>gv=gv";
        options = {
          desc = "Move line down";
        };
      }
      {
        mode = "v";
        key = "K";
        action = ":m '<-2<cr>gv=gv";
        options = {
          desc = "Move line up";
        };
      }

      # Better indenting
      {
        mode = "v";
        key = "<";
        action = "<gv";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
      }

      # Keep cursor centered when scrolling
      {
        mode = "n";
        key = "<C-d>";
        action = "<C-d>zz";
      }
      {
        mode = "n";
        key = "<C-u>";
        action = "<C-u>zz";
      }
    ];

    # Additional Lua configuration
    extraConfigLua = ''
      -- Make line numbers default in netrw
      vim.g.netrw_bufsettings = 'noma nomod nu nobl nowrap ro'

      -- Highlight on yank
      vim.api.nvim_create_autocmd('TextYankPost', {
        callback = function()
          vim.highlight.on_yank({ timeout = 200 })
        end,
      })
    '';
  };
}
