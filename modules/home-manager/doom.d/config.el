;;; config.el -*- lexical-binding: t; -*-

(setq user-full-name "Brandon Orther"
      user-mail-address "brandon@orther.dev")

;; Configure tree-sitter grammar paths
(when (boundp 'treesit-extra-load-path)
  (add-to-list 'treesit-extra-load-path (expand-file-name "~/.tree-sitter")))

;; Enable auto-imports for JavaScript/TypeScript
(after! lsp-mode
  ;; Enable automatic import suggestions
  (setq lsp-completion-enable-additional-text-edit t)

  ;; Make sure code actions are available (for organize imports, etc.)
  (setq lsp-enable-symbol-highlighting t)
  (setq lsp-signature-auto-activate t)

  ;; Enable auto-imports specifically for JS/TS
  (setq lsp-typescript-suggest-auto-imports t)
  (setq lsp-javascript-suggest-auto-imports t))

;; Configure company mode for better completion experience
(after! company
  ;; Faster completion trigger
  (setq company-idle-delay 0.2)
  (setq company-minimum-prefix-length 1)

  ;; Better sorting with LSP
  (setq company-transformers '(company-sort-by-occurrence)))

;; Fix editorconfig void-variable error - define before package loads
(defvar editorconfig-exclude-regexps nil
  "List of regexps to exclude files from editorconfig processing.")

;; Place any additional user settings here.

