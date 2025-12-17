;;; sleek-modeline.el --- Minimal and elegant modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo

;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; Version: 1.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: mode-line, faces
;; URL: https://github.com/abidanBrito/sleek-modeline
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; This package provides a minimal and elegant modeline replacement.

;;; Code:

(require 'sleek-modeline-helpers)

(defvar sleek-modeline-format
  '("%e"
    " "
    (:eval (sleek-modeline-modal-state-marker))
    (:eval (sleek-modeline-buffer-name))
    " "
    (:eval (sleek-modeline-major-mode)))
  "The sleek mode-line format.")

(defvar sleek-modeline--default-mode-line mode-line-format
  "Storage for the default `mode-line-format'.")

;;;###autoload
(define-minor-mode sleek-modeline-mode
  "Toggle sleek modeline on and off."
  :global t
  :group 'sleek-modeline
  (if sleek-modeline-mode
      (progn
        (setq sleek-modeline--default-mode-line mode-line-format)
        (setq-default mode-line-format sleek-modeline-format))
    (setq-default mode-line-format sleek-modeline--default-mode-line))
  (force-mode-line-update t))

(provide 'sleek-modeline)

;;; sleek-modeline.el ends here
