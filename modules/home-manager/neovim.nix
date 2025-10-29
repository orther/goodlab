{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
  ];

  programs.nixvim = {
    enable = true;

    # Optional: Set as default editor (currently Helix is default)
    # defaultEditor = true;

    # Vim aliases for muscle memory
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Basic Neovim settings
    opts = {
      # Line numbers
      number = true;
      relativenumber = true;

      # Indentation
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      expandtab = true;
      smartindent = true;
      autoindent = true;

      # Search
      ignorecase = true;
      smartcase = true;
      hlsearch = false;
      incsearch = true;

      # UI
      wrap = false;
      scrolloff = 8;
      signcolumn = "yes";
      cursorline = true;
      termguicolors = true;
      colorcolumn = "100";

      # Files
      swapfile = false;
      backup = false;
      undofile = true;
      updatetime = 50;

      # Splits
      splitbelow = true;
      splitright = true;

      # Completion
      completeopt = "menu,menuone,noselect";

      # Mouse support
      mouse = "a";

      # Clipboard integration (works with tmux)
      clipboard = "unnamedplus";
    };

    # Global variables
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # Colorscheme
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = false;
        term_colors = true;
        integrations = {
          cmp = true;
          gitsigns = true;
          treesitter = true;
          telescope.enabled = true;
          native_lsp = {
            enabled = true;
            virtual_text = {
              errors = ["italic"];
              hints = ["italic"];
              warnings = ["italic"];
              information = ["italic"];
            };
            underlines = {
              errors = ["underline"];
              hints = ["underline"];
              warnings = ["underline"];
              information = ["underline"];
            };
          };
        };
      };
    };

    # Treesitter configuration
    plugins.treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        incremental_selection.enable = true;
      };

      # Install grammars via nixpkgs for reproducibility
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        # Requested languages
        typescript
        tsx
        javascript
        graphql
        elixir
        heex # Phoenix templates
        nix
        bash
        yaml
        dockerfile

        # Neovim essentials
        lua
        vim
        vimdoc
        query

        # Common formats and languages
        json
        toml
        markdown
        markdown_inline
        regex
        html
        css
        go
        python
        rust
        c
        cpp
      ];
    };

    # LSP configuration
    plugins.lsp = {
      enable = true;

      # LSP servers for requested languages
      servers = {
        # TypeScript/TSX/JavaScript
        ts_ls = {
          enable = true;
          filetypes = ["typescript" "typescriptreact" "javascript" "javascriptreact"];
        };

        # Elixir
        elixirls = {
          enable = true;
        };

        # Nix (using nil - recommended)
        nil_ls = {
          enable = true;
          settings = {
            formatting.command = ["alejandra"];
            nix = {
              flake = {
                autoArchive = true;
                autoEvalInputs = true;
              };
            };
          };
        };

        # Bash/Zsh
        bashls = {
          enable = true;
          filetypes = ["sh" "bash" "zsh"];
        };

        # YAML
        yamlls = {
          enable = true;
          settings = {
            yaml = {
              schemas = {
                kubernetes = "*.yaml";
                "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*";
                "https://json.schemastore.org/docker-compose.json" = "docker-compose*.yml";
              };
              format.enable = true;
              validate = true;
            };
          };
        };

        # Docker
        dockerls = {
          enable = true;
        };

        docker_compose_language_service = {
          enable = true;
        };

        # Lua (for Neovim config)
        lua_ls = {
          enable = true;
          settings = {
            telemetry.enable = false;
            diagnostics = {
              globals = ["vim"];
            };
          };
        };

        # Markdown
        marksman = {
          enable = true;
        };

        # JSON
        jsonls = {
          enable = true;
        };
      };

      # LSP keymaps
      keymaps = {
        diagnostic = {
          "<leader>e" = "open_float";
          "[d" = "goto_prev";
          "]d" = "goto_next";
          "<leader>q" = "setloclist";
        };

        lspBuf = {
          "gd" = "definition";
          "gD" = "declaration";
          "gi" = "implementation";
          "gr" = "references";
          "K" = "hover";
          "<C-k>" = "signature_help";
          "<leader>wa" = "add_workspace_folder";
          "<leader>wr" = "remove_workspace_folder";
          "<leader>D" = "type_definition";
          "<leader>rn" = "rename";
          "<leader>ca" = "code_action";
          "<leader>f" = "format";
        };
      };
    };

    # Completion with nvim-cmp
    plugins.cmp = {
      enable = true;
      autoEnableSources = true;

      settings = {
        sources = [
          {name = "nvim_lsp";}
          {name = "path";}
          {name = "buffer";}
        ];

        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.close()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
          "<C-d>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
        };

        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
      };
    };

    # Snippet engine (required for nvim-cmp)
    plugins.luasnip = {
      enable = true;
    };

    # File explorer
    plugins.neo-tree = {
      enable = true;
      closeIfLastWindow = true;
      window = {
        width = 30;
        mappings = {
          "<space>" = "toggle_node";
          "<cr>" = "open";
          "S" = "open_split";
          "s" = "open_vsplit";
        };
      };
      filesystem = {
        followCurrentFile = {
          enabled = true;
        };
        useLibuvFileWatcher = true;
      };
    };

    # Fuzzy finder
    plugins.telescope = {
      enable = true;
      keymaps = {
        "<leader>ff" = {
          action = "find_files";
          options.desc = "Find files";
        };
        "<leader>fg" = {
          action = "live_grep";
          options.desc = "Live grep";
        };
        "<leader>fb" = {
          action = "buffers";
          options.desc = "Buffers";
        };
        "<leader>fh" = {
          action = "help_tags";
          options.desc = "Help tags";
        };
        "<leader>fr" = {
          action = "oldfiles";
          options.desc = "Recent files";
        };
        "<leader>fc" = {
          action = "commands";
          options.desc = "Commands";
        };
      };
      extensions = {
        fzf-native = {
          enable = true;
        };
      };
    };

    # Git integration
    plugins.gitsigns = {
      enable = true;
      settings = {
        current_line_blame = true;
        current_line_blame_opts = {
          delay = 300;
        };
      };
    };

    plugins.fugitive = {
      enable = true;
    };

    # Status line
    plugins.lualine = {
      enable = true;
      settings = {
        options = {
          icons_enabled = true;
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
        sections = {
          lualine_a = ["mode"];
          lualine_b = ["branch" "diff" "diagnostics"];
          lualine_c = ["filename"];
          lualine_x = ["encoding" "fileformat" "filetype"];
          lualine_y = ["progress"];
          lualine_z = ["location"];
        };
      };
    };

    # Auto pairs
    plugins.nvim-autopairs = {
      enable = true;
    };

    # Comment shortcuts (gcc, gbc)
    plugins.comment = {
      enable = true;
    };

    # Indent guides
    plugins.indent-blankline = {
      enable = true;
      settings = {
        scope = {
          enabled = true;
        };
      };
    };

    # Better terminal
    plugins.toggleterm = {
      enable = true;
      settings = {
        size = 20;
        open_mapping = "[[<C-\\>]]";
        direction = "horizontal";
        shade_terminals = true;
      };
    };

    # Which-key for keybinding hints
    plugins.which-key = {
      enable = true;
    };

    # Tmux integration for seamless navigation
    plugins.vim-tmux-navigator = {
      enable = true;
    };

    # Additional useful plugins
    plugins.surround = {
      enable = true;
    };

    plugins.nvim-colorizer = {
      enable = true;
      userDefaultOptions = {
        names = false;
      };
    };

    # Key mappings
    keymaps = [
      # File explorer
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle file explorer";
      }

      # Buffer navigation
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<cr>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options.desc = "Delete buffer";
      }

      # Window navigation (works seamlessly with tmux via vim-tmux-navigator)
      {
        mode = "n";
        key = "<C-h>";
        action = "<cmd>TmuxNavigateLeft<cr>";
        options.desc = "Navigate left (tmux-aware)";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<cmd>TmuxNavigateDown<cr>";
        options.desc = "Navigate down (tmux-aware)";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<cmd>TmuxNavigateUp<cr>";
        options.desc = "Navigate up (tmux-aware)";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<cmd>TmuxNavigateRight<cr>";
        options.desc = "Navigate right (tmux-aware)";
      }

      # Window resizing
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<cr>";
        options.desc = "Increase window height";
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<cr>";
        options.desc = "Decrease window height";
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<cr>";
        options.desc = "Decrease window width";
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<cr>";
        options.desc = "Increase window width";
      }

      # Save and quit
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options.desc = "Save file";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options.desc = "Quit";
      }
      {
        mode = "n";
        key = "<leader>Q";
        action = "<cmd>qa<cr>";
        options.desc = "Quit all";
      }

      # Clear search highlights
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
        options.desc = "Clear search highlights";
      }

      # Better indenting
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options.desc = "Indent left";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options.desc = "Indent right";
      }

      # Move lines
      {
        mode = "n";
        key = "<A-j>";
        action = "<cmd>m .+1<cr>==";
        options.desc = "Move line down";
      }
      {
        mode = "n";
        key = "<A-k>";
        action = "<cmd>m .-2<cr>==";
        options.desc = "Move line up";
      }
      {
        mode = "v";
        key = "<A-j>";
        action = ":m '>+1<cr>gv=gv";
        options.desc = "Move selection down";
      }
      {
        mode = "v";
        key = "<A-k>";
        action = ":m '<-2<cr>gv=gv";
        options.desc = "Move selection up";
      }

      # Git shortcuts
      {
        mode = "n";
        key = "<leader>gs";
        action = "<cmd>Git<cr>";
        options.desc = "Git status (fugitive)";
      }
      {
        mode = "n";
        key = "<leader>gc";
        action = "<cmd>Git commit<cr>";
        options.desc = "Git commit";
      }
      {
        mode = "n";
        key = "<leader>gp";
        action = "<cmd>Git push<cr>";
        options.desc = "Git push";
      }
      {
        mode = "n";
        key = "<leader>gl";
        action = "<cmd>Git log<cr>";
        options.desc = "Git log";
      }
    ];

    # Extra configuration for tmux integration
    extraConfigLua = ''
      -- Ensure proper terminal colors in tmux
      if vim.env.TMUX then
        vim.opt.termguicolors = true
      end

      -- Better clipboard integration with tmux
      if vim.env.TMUX then
        vim.g.clipboard = {
          name = 'tmux',
          copy = {
            ['+'] = {'tmux', 'load-buffer', '-'},
            ['*'] = {'tmux', 'load-buffer', '-'},
          },
          paste = {
            ['+'] = {'tmux', 'save-buffer', '-'},
            ['*'] = {'tmux', 'save-buffer', '-'},
          },
          cache_enabled = 1,
        }
      end

      -- Diagnostic signs
      local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- Highlight on yank
      vim.api.nvim_create_autocmd('TextYankPost', {
        callback = function()
          vim.highlight.on_yank({ timeout = 200 })
        end,
      })
    '';
  };
}
