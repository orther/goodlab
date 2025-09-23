;;; init.el -*- lexical-binding: t; -*-

;; Minimal Doom modules to get started
(doom! :input
       :completion
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
       (magit +forge)
       direnv
       editorconfig
       :os
       macos
       :lang
       emacs-lisp
       markdown
       nix
       :config
       (default +bindings +smartparens))

