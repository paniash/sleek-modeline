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

(require 'sleek-modeline-core)
(require 'sleek-modeline-vc)

;; Declare segment functions to quiet the byte-compiler
(declare-function sleek-modeline-diagnostics-enable "sleek-modeline-diagnostics")
(declare-function sleek-modeline-diagnostics-disable "sleek-modeline-diagnostics")
(declare-function sleek-modeline-project "sleek-modeline-project")
(declare-function sleek-modeline-project-enable "sleek-modeline-project")
(declare-function sleek-modeline-project-disable "sleek-modeline-project")

(defcustom sleek-modeline-enable-diagnostics t
  "Enable diagnostics segment integration in sleek-modeline."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-enable-project t
  "Enable project name segment integration in sleek-modeline.
Supports `projectile' and the built-in `project.el', preferring
projectile when both are active."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-edge-padding 2
  "Number of spaces at the left and right edges of the mode-line."
  :type 'integer
  :group 'sleek-modeline)

(defvar sleek-modeline--saved-modeline-attrs nil
  "Saved `mode-line' face attributes before sleek-modeline modified them.")

(defvar sleek-modeline--saved-modeline-inactive-attrs nil
  "Saved `mode-line-inactive' face attributes before sleek-modeline modified them.")

(defvar sleek-modeline-format
  '("%e"
    (:eval (make-string sleek-modeline-edge-padding ?\s))
    (:eval (when-let ((marker (sleek-modeline-modal-state-marker)))
             (concat marker " ")))
    (:eval (when sleek-modeline-enable-project
             (when-let ((proj (sleek-modeline-project)))
               (concat proj (sleek-modeline--separator)))))
    (:eval (sleek-modeline-buffer-name))
    mode-line-format-right-align
    (:eval (when-let ((diag (sleek-modeline-diagnostics)))
             (concat diag (sleek-modeline--separator))))
    (:eval (when-let ((eol (sleek-modeline-line-ending-indicator)))
             (unless (string-empty-p eol)
               (concat eol (sleek-modeline--separator)))))
    (:eval (when-let ((vc (sleek-modeline-vc)))
             (concat vc (sleek-modeline--separator))))
    (:eval (sleek-modeline-major-mode))
    (:eval (make-string sleek-modeline-edge-padding ?\s)))
  "The sleek mode-line format.")

(defvar sleek-modeline--default-mode-line mode-line-format
  "Storage for the default `mode-line-format'.")

(defun sleek-modeline--after-theme-change (&rest _)
  "Update faces after theme change."
  (run-with-timer 0.1 nil #'sleek-modeline--update-faces))

;;;###autoload
(define-minor-mode sleek-modeline-mode
  "Toggle sleek modeline on and off."
  :global t
  :group 'sleek-modeline
  (if sleek-modeline-mode
      (progn
	;; Save original format & face attributes
	(unless (eq (default-value 'mode-line-format) sleek-modeline-format)
	  (setq sleek-modeline--default-mode-line
		(default-value 'mode-line-format))
          (setq sleek-modeline--saved-modeline-attrs
		(list :background (face-attribute 'mode-line :background nil t)
                      :box (face-attribute 'mode-line :box nil t)
                      :underline (face-attribute 'mode-line :underline nil t)
                      :overline (face-attribute 'mode-line :overline nil t)))
          (setq sleek-modeline--saved-modeline-inactive-attrs
		(list :background (face-attribute 'mode-line-inactive :background nil t)
                      :box (face-attribute 'mode-line-inactive :box nil t)
                      :underline (face-attribute 'mode-line-inactive :underline nil t)
                      :overline (face-attribute 'mode-line-inactive :overline nil t))))

	;; Apply `sleek-modeline' format
        (setq-default mode-line-format sleek-modeline-format)

	;; Update faces after a theme change
        (add-hook 'after-load-theme-hook #'sleek-modeline--update-faces)
        (advice-add 'load-theme :after #'sleek-modeline--after-theme-change)
        (advice-add 'enable-theme :after #'sleek-modeline--after-theme-change)

	;; Enable diagnostics segment if configured
	(when sleek-modeline-enable-diagnostics
	  (require 'sleek-modeline-diagnostics nil t)
	  (sleek-modeline-diagnostics-enable))

	;; Enable project segment if configured
	(when sleek-modeline-enable-project
	  (require 'sleek-modeline-project nil t))

        (sleek-modeline--update-faces))

    ;; Restore original format & face attributes
    (setq-default mode-line-format sleek-modeline--default-mode-line)

    ;; Restore saved faces
    (when sleek-modeline--saved-modeline-attrs
      (apply #'set-face-attribute 'mode-line nil
             sleek-modeline--saved-modeline-attrs))
    (when sleek-modeline--saved-modeline-inactive-attrs
      (apply #'set-face-attribute 'mode-line-inactive nil
             sleek-modeline--saved-modeline-inactive-attrs))

    ;; Remove hooks and advices added by sleek-modeline
    (remove-hook 'after-load-theme-hook #'sleek-modeline--update-faces)
    (advice-remove 'load-theme #'sleek-modeline--after-theme-change)
    (advice-remove 'enable-theme #'sleek-modeline--after-theme-change)

    ;; Disable diagnostics segment if enabled
    (when sleek-modeline-enable-diagnostics
      (sleek-modeline-diagnostics-disable)))

  (force-mode-line-update t))

(provide 'sleek-modeline)
;;; sleek-modeline.el ends here
