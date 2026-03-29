;;; sleek-modeline-diagnostics.el --- Diagnostics segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Diagnostics (checker/linter) control segment for the `sleek-modeline' package.
;; Supports flycheck showing error, warning and info counts.  The cache is hook-driven,
;; i.e, it updates only when a checker finishes.

;;; Code:

(require 'sleek-modeline-core)

;; Optional dependencies, declared to silence the byte-compiler
;; NOTE(abi): these get loaded only if available.
(eval-when-compile
  (declare-function flycheck-count-errors "flycheck")
  (declare-function nerd-icons-codicon "nerd-icons")
  (defvar flycheck-mode)
  (defvar flycheck-current-errors))

(defvar sleek-modeline-diagnostics--enabled nil
  "Non-nil means diagnostics integration with Flycheck is enabled globally.
Used as a sentinel to ensure hooks are only installed once.")

(defvar-local sleek-modeline-diagnostics--cache nil
  "Cached propertized string for the diagnostics segment.
Nil means the cache is empty (no checker result yet).")

(defcustom sleek-modeline-diagnostics-show-info t
  "Whether to show info-level diagnostics in the mode-line."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-diagnostics-error-symbol "✕"
  "Symbol used to indicate errors."
  :type 'string
  :group 'sleek-modeline)

(defcustom sleek-modeline-diagnostics-warning-symbol "▲"
  "Symbol used to indicate warnings."
  :type 'string
  :group 'sleek-modeline)

(defcustom sleek-modeline-diagnostics-info-symbol "●"
  "Symbol used to indicate info notes."
  :type 'string
  :group 'sleek-modeline)

(defcustom sleek-modeline-diagnostics-ok-symbol nil
  "Symbol shown when there are no diagnostics and the checker passed.
When nil, nothing is shown for a clean buffer."
  :type '(choice (const :tag "Nothing" nil)
                 (string :tag "Symbol"))
  :group 'sleek-modeline)

(defface sleek-modeline-diagnostics-error-face
  '((t (:inherit error :weight bold)))
  "Face for error count in diagnostics segment."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-diagnostics-warning-face
  '((t (:inherit warning :weight bold)))
  "Face for warning count in diagnostics segment."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-diagnostics-info-face
  '((t (:inherit success :weight bold)))
  "Face for info count in diagnostics segment."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-diagnostics-ok-face
  '((t (:inherit font-lock-comment-face)))
  "Face used when there are no diagnostics."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-diagnostics--icon (nerd-icon fallback)
  "Return a diagnostic icon string.
Uses NERD-ICON from `nerd-icons' if available and icons are enabled,
otherwise returns FALLBACK."
  (if (and sleek-modeline-show-icons (featurep 'nerd-icons))
      (nerd-icons-codicon nerd-icon)
    fallback))

(defun sleek-modeline-diagnostics--format (errors warnings infos)
  "Build a propertized string from ERRORS, WARNINGS and INFOS counts.
Returns nil when all counts are zero and `sleek-modeline-diagnostics-ok-symbol'
is nil."
  (if (and (zerop errors) (zerop warnings) (zerop infos))
      (when sleek-modeline-diagnostics-ok-symbol
        (propertize sleek-modeline-diagnostics-ok-symbol
                    'face 'sleek-modeline-diagnostics-ok-face))
    (let (parts)
      (when (and sleek-modeline-diagnostics-show-info (> infos 0))
        (push (propertize (format "%s %d"
                                  (sleek-modeline-diagnostics--icon
                                   "nf-cod-lightbulb"
                                   sleek-modeline-diagnostics-info-symbol)
                                  infos)
                          'face 'sleek-modeline-diagnostics-info-face)
              parts))
      (when (> warnings 0)
        (push (propertize (format "%s %d"
                                  (sleek-modeline-diagnostics--icon
                                   "nf-cod-warning"
                                   sleek-modeline-diagnostics-warning-symbol)
                                  warnings)
                          'face 'sleek-modeline-diagnostics-warning-face)
              parts))
      (when (> errors 0)
        (push (propertize (format "%s %d"
                                  (sleek-modeline-diagnostics--icon
                                   "nf-cod-error"
                                   sleek-modeline-diagnostics-error-symbol)
                                  errors)
                          'face 'sleek-modeline-diagnostics-error-face)
              parts))
      (when parts
        (string-join parts " ")))))

(defun sleek-modeline-diagnostics--flycheck-update ()
  "Recompute the diagnostics cache from the current flycheck state."
  (setq sleek-modeline-diagnostics--cache
        (when (bound-and-true-p flycheck-mode)
          (let* ((counts   (flycheck-count-errors flycheck-current-errors))
                 (errors   (or (cdr (assq 'error   counts)) 0))
                 (warnings (or (cdr (assq 'warning counts)) 0))
                 (infos    (or (cdr (assq 'info    counts)) 0)))
            (sleek-modeline-diagnostics--format errors warnings infos))))
  (force-mode-line-update))

(defun sleek-modeline-diagnostics--flycheck-setup ()
  "Attach flycheck hooks for the current buffer."
  (add-hook 'flycheck-after-syntax-check-hook
            #'sleek-modeline-diagnostics--flycheck-update nil t))

(defun sleek-modeline-diagnostics--flycheck-teardown ()
  "Remove flycheck hooks and clear cache for the current buffer."
  (remove-hook 'flycheck-after-syntax-check-hook
               #'sleek-modeline-diagnostics--flycheck-update t)
  (setq sleek-modeline-diagnostics--cache nil))

(defun sleek-modeline-diagnostics--flycheck-mode-hook ()
  "Setup or tear down flycheck integration based on `flycheck-mode' state."
  (if flycheck-mode
      (sleek-modeline-diagnostics--flycheck-setup)
    (sleek-modeline-diagnostics--flycheck-teardown)))

(defun sleek-modeline-diagnostics ()
  "Return the propertized diagnostics string for the current buffer, or nil.
The value is read from a hook-driven cache - no work is done on redraw."
  sleek-modeline-diagnostics--cache)

;;;###autoload
(defun sleek-modeline-diagnostics-enable ()
  "Enable diagnostics segment wiring.
Attaches to Flycheck/Flymake mode hooks so that diagnostics tracking
is integrated automatically in buffers where a checker activates.
Call this once inside `sleek-modeline-mode' activation."
  (unless sleek-modeline-diagnostics--enabled
    (setq sleek-modeline-diagnostics--enabled t)
    (when (featurep 'flycheck)
      (add-hook 'flycheck-mode-hook
		#'sleek-modeline-diagnostics--flycheck-mode-hook))))

(defun sleek-modeline-diagnostics-disable ()
  "Disable diagnostics segment integration.
Removes the global Flycheck/Flymake hooks and tears down diagnostics
tracking in all existing buffers where it was active.
This ensures no buffer-local hooks or cached state remain."
  (when sleek-modeline-diagnostics--enabled
    (setq sleek-modeline-diagnostics--enabled nil)
    (when (featurep 'flycheck)
      (remove-hook 'flycheck-mode-hook
                   #'sleek-modeline-diagnostics--flycheck-mode-hook))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
	(when (bound-and-true-p flycheck-mode)
          (sleek-modeline-diagnostics--flycheck-teardown))))))

(provide 'sleek-modeline-diagnostics)
;;; sleek-modeline-diagnostics.el ends here
