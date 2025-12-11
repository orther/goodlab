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
  (setq lsp-javascript-suggest-auto-imports t)

  ;; Enable inline type hints for TypeScript
  (setq lsp-typescript-inlay-hints-include-infer-parameter-type-hints t)
  (setq lsp-typescript-inlay-hints-include-infer-property-declaration-type-hints t)

  ;; Enable error checking and diagnostics
  (setq lsp-diagnostics-provider :auto)
  (setq lsp-ui-sideline-show-diagnostics t)
  (setq lsp-ui-sideline-show-code-actions t)

  ;; Enable flycheck for type checking
  (setq lsp-prefer-flymake nil))

;; Configure TypeScript/TSX modes
(after! typescript-mode
  ;; Use tree-sitter for better syntax highlighting
  (setq typescript-indent-level 2)

  ;; Enable LSP for TypeScript files
  (add-hook 'typescript-mode-hook #'lsp!)
  (add-hook 'typescript-tsx-mode-hook #'lsp!))

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

;; Configure markdown preview with marked
(after! markdown-mode
  ;; Use marked for markdown preview
  (setq markdown-command "marked")
  ;; Enable live preview
  (setq markdown-live-preview-engine 'marked))

;; Place any additional user settings here.

