;;; config.el -*- lexical-binding: t; -*-

(setq user-full-name "Brandon Orther"
      user-mail-address "brandon@orther.dev")

;; Configure tree-sitter grammar paths
(when (boundp 'treesit-extra-load-path)
  (add-to-list 'treesit-extra-load-path (expand-file-name "~/.tree-sitter")))

;; Place any additional user settings here.

