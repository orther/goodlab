;;; packages.el -*- lexical-binding: t; -*-

;; Example: (package! some-package)

;; Use built-in editorconfig in Emacs 30.2+ instead of the package
;; This prevents conflicts between the built-in and package versions
(package! editorconfig :built-in 'prefer)

