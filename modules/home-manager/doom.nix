{
  inputs,
  pkgs,
  lib,
  ...
}: let
  # Tree-sitter grammars for various languages
  treesitterGrammars = pkgs.tree-sitter.withPlugins (grammars:
    with grammars; [
      tree-sitter-typescript
      tree-sitter-tsx
      tree-sitter-javascript
      tree-sitter-json
      tree-sitter-css
      tree-sitter-html
      tree-sitter-bash
      tree-sitter-markdown
      tree-sitter-nix
    ]);
in {
  programs.emacs = {
    enable = true;
    package =
      if pkgs.stdenv.isDarwin
      then pkgs.emacs-macport
      else pkgs.emacs;
  };

  home = {
    # Link Doom core and your Doom config into $HOME
    file = {
      ".config/emacs".source = inputs.doom-emacs;
      ".config/doom".source = ./doom.d;
    };

    # Install tree-sitter grammars and Doom dependencies
    packages = [
      treesitterGrammars
      pkgs.ripgrep # Required for file/text search
      pkgs.fd # Fast file finder
      pkgs.coreutils # For gls (GNU ls) on macOS
      pkgs.cmake # Required for vterm compilation
      pkgs.nodejs # Required for marked (markdown preview)
      pkgs.nodePackages.npm # For installing marked globally
    ];

    # Ensure `doom` CLI is on PATH for activation scripts
    sessionPath = lib.mkIf pkgs.stdenv.isDarwin (lib.mkAfter ["$HOME/.config/emacs/bin"]);
  };

  # Symlink Emacs.app to ~/Applications for Spotlight
  home.activation.linkEmacsApp = lib.hm.dag.entryAfter ["writeBoundary"] (
    lib.mkIf pkgs.stdenv.isDarwin ''
      mkdir -p $HOME/Applications
      app_path="${pkgs.emacs-macport}/Applications/Emacs.app"
      if [ -d "$app_path" ]; then
        $DRY_RUN_CMD rm -rf $HOME/Applications/Emacs.app
        $DRY_RUN_CMD ln -sf "$app_path" $HOME/Applications/Emacs.app
      fi
    ''
  );

  # Create symlinks for tree-sitter grammars with proper naming
  home.activation.linkTreeSitterGrammars = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.tree-sitter

    # Create symlinks for each grammar with the naming pattern Emacs expects
    ${pkgs.lib.concatMapStringsSep "\n" (grammar: let
        name = grammar.pname or (builtins.parseDrvName grammar.name).name;
        langName =
          if name == "tree-sitter-typescript-grammar"
          then "typescript"
          else if name == "tree-sitter-tsx-grammar"
          then "tsx"
          else if name == "tree-sitter-javascript-grammar"
          then "javascript"
          else if name == "tree-sitter-json-grammar"
          then "json"
          else if name == "tree-sitter-css-grammar"
          then "css"
          else if name == "tree-sitter-html-grammar"
          then "html"
          else if name == "tree-sitter-bash-grammar"
          then "bash"
          else if name == "tree-sitter-markdown-grammar"
          then "markdown"
          else if name == "tree-sitter-nix-grammar"
          then "nix"
          else "";
      in ''
        ln -sf ${grammar}/parser $HOME/.tree-sitter/libtree-sitter-${langName}.dylib
      '') (with pkgs.tree-sitter-grammars; [
        tree-sitter-typescript
        tree-sitter-tsx
        tree-sitter-javascript
        tree-sitter-json
        tree-sitter-css
        tree-sitter-html
        tree-sitter-bash
        tree-sitter-markdown
        tree-sitter-nix
      ])}
  '';

  # Install marked globally for markdown preview
  home.activation.installMarked = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! command -v marked >/dev/null 2>&1; then
      echo "Installing marked for Emacs markdown preview..."
      export PATH="${pkgs.nodejs}/bin:${pkgs.nodePackages.npm}/bin:$PATH"
      $DRY_RUN_CMD npm install -g marked || true
    fi
  '';

  # Sync Doom packages after HM writes files (best-effort)
  home.activation.doomSync = lib.hm.dag.entryAfter ["writeBoundary"] (let
    emacsPackage =
      if pkgs.stdenv.isDarwin
      then pkgs.emacs-macport
      else pkgs.emacs;
  in ''
    if [ -x "$HOME/.config/emacs/bin/doom" ]; then
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
      export DOOMLOCALDIR="$XDG_DATA_HOME/doom"
      export DOOMDATA="$XDG_DATA_HOME/doom/data"
      export DOOMCACHE="$XDG_CACHE_HOME/doom"
      export DOOMSTATE="$XDG_STATE_HOME/doom"
      export PATH="${emacsPackage}/bin:${pkgs.git}/bin:${pkgs.ripgrep}/bin:${pkgs.fd}/bin:$PATH"
      # Use -! to force sync without prompting
      "$HOME/.config/emacs/bin/doom" sync -! || true
    fi
  '');
}
