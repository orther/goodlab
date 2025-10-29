;;; init.el -*- lexical-binding: t; -*-

;; Minimal Doom modules to get started
(doom! :input
       :completion
       company
       vertico
       :ui
       doom
       modeline
       workspaces
       :editor
       (evil +everywhere)
       file-templates
       fold
       :emacs
       dired
       vc
       :term
       vterm
       :checkers
       syntax
       :tools
       docker
       (lsp +peek)
       tree-sitter
       (magit +forge)
       direnv
       editorconfig
       :os
       macos
       :lang
       elixir
       emacs-lisp
       erlang
       graphql
       (javascript +lsp +tree-sitter)
       markdown
       nix
       sh
       yaml
       :config
       (default +bindings +smartparens))

