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
       (lsp +peek)
       tree-sitter
       (magit +forge)
       direnv
       editorconfig
       :os
       macos
       :lang
       emacs-lisp
       (javascript +lsp +tree-sitter)
       markdown
       nix
       :config
       (default +bindings +smartparens))

