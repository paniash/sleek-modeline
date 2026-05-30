;;; sleek-modeline.el --- Minimal and elegant modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo

;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: mode-line, faces
;; URL: https://github.com/abidanBrito/sleek-modeline
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; This package provides a minimal and elegant modeline replacement.

;;; Code:

(require 'sleek-modeline-core)
(require 'sleek-modeline-vc)

;; Declare segment functions to quiet the byte-compiler
(declare-function sleek-modeline-vc-enable "sleek-modeline-vc")
(declare-function sleek-modeline-vc-disable "sleek-modeline-vc")
(declare-function sleek-modeline-diagnostics-enable "sleek-modeline-diagnostics")
(declare-function sleek-modeline-diagnostics-disable "sleek-modeline-diagnostics")
(declare-function sleek-modeline-project "sleek-modeline-project")
(declare-function sleek-modeline-project-enable "sleek-modeline-project")
(declare-function sleek-modeline-project-disable "sleek-modeline-project")
(declare-function sleek-modeline-lsp "sleek-modeline-lsp")
(declare-function sleek-modeline-lsp-enable "sleek-modeline-lsp")
(declare-function sleek-modeline-lsp-disable "sleek-modeline-lsp")

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

(defcustom sleek-modeline-enable-lsp t
  "Enable LSP segment integration in sleek-modeline.
Supports `eglot' and `lsp-mode' backends."
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
    (:eval (when-let ((lsp (sleek-modeline-lsp)))
             (concat lsp (sleek-modeline--separator))))
    (:eval (sleek-modeline-major-mode))
    (:eval (make-string sleek-modeline-edge-padding ?\s)))
  "The sleek mode-line format.")

(defvar sleek-modeline--default-mode-line mode-line-format
  "Storage for the default `mode-line-format'.")

(defun sleek-modeline--segment-eval-form (seg)
  "Return an (:eval ...) mode-line form for segment SEG."
  (let* ((fn (plist-get seg :fn))
         (sep (plist-get seg :separator))
         (cond-var (plist-get seg :condition))
         (core (if sep
                   (let ((suffix (if (eq sep t)
                                     '(sleek-modeline--separator)
                                   sep)))
                     `(when-let ((result (,fn)))
                        (concat result ,suffix)))
                 `(,fn)))
         (form (if cond-var `(when ,cond-var ,core) core)))
    `(:eval ,form)))

(defun sleek-modeline--build-format ()
  "Rebuild `sleek-modeline-format' from the segment registry."
  (let* ((by-priority (lambda (a b)
                        (< (plist-get a :priority) (plist-get b :priority))))
         (left  (sort (seq-filter (lambda (s) (eq (plist-get s :side) 'left))
                                  sleek-modeline--segment-registry)
                      by-priority))
         (right (sort (seq-filter (lambda (s) (eq (plist-get s :side) 'right))
                                  sleek-modeline--segment-registry)
                      by-priority)))
    (setq sleek-modeline-format
          `("%e"
            (:eval (make-string sleek-modeline-edge-padding ?\s))
            ,@(mapcar #'sleek-modeline--segment-eval-form left)
            mode-line-format-right-align
            ,@(mapcar #'sleek-modeline--segment-eval-form right)
            (:eval (make-string sleek-modeline-edge-padding ?\s))))))

(defun sleek-modeline--after-theme-change (&rest _)
  "Update faces after theme change."
  (run-with-timer 0.1 nil #'sleek-modeline--update-faces))

(defun sleek-modeline--real-frame-p (frame)
  "Return non-nil when FRAME is a real (non-daemon-initial) frame.
The daemon creates an invisible stub frame associated with the special
terminal named \"initial_terminal\".  That frame reports `framep' as t
and `frame-visible-p' as t, so those predicates cannot distinguish it
from a real TTY frame.  We match its terminal name directly, matching
the approach used inside Emacs' own `debug.el'.  Nil FRAME means the
selected frame."
  (let ((f (or frame (selected-frame))))
    (and (frame-live-p f)
         (not (string-equal (terminal-name (frame-terminal f))
                            "initial_terminal")))))

(defun sleek-modeline--graphical-frame-exists-p ()
  "Return non-nil when at least one real client frame exists.
A \"real\" frame is either graphical or a TTY, excluding the daemon's
initial invisible stub."
  (and (not noninteractive)
       (cl-some #'sleek-modeline--real-frame-p (frame-list))))

(defun sleek-modeline--deferred-face-update (&optional frame)
  "Recompute mode-line faces once a real client frame is available.
Designed to be hung on `server-after-make-frame-hook' and
`after-make-frame-functions'.  Runs a single face update in the
context of FRAME (or the selected frame) on an idle timer so that
face realisation on the new frame has a chance to complete before
we read `(face-background 'default ...)'."
  (when (and sleek-modeline-mode
             (sleek-modeline--real-frame-p frame))
    (remove-hook 'server-after-make-frame-hook
                 #'sleek-modeline--deferred-face-update)
    (remove-hook 'after-make-frame-functions
                 #'sleek-modeline--deferred-face-update)

    ;; Defer to the next idle moment so that the new frame is fully
    ;; realised (theme applied, `default' background set).  Without this,
    ;; `face-background' can still return the pre-theme colour that the
    ;; daemon's initial frame had.
    (let ((target-frame (or frame (selected-frame))))
      (run-with-idle-timer
       0 nil
       (lambda ()
         (when (frame-live-p target-frame)
           (with-selected-frame target-frame
             (sleek-modeline--update-faces))))))))

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

	;; Enable vc segment cache hooks
        (sleek-modeline-vc-enable)

	;; Enable diagnostics segment if configured
	(when sleek-modeline-enable-diagnostics
	  (require 'sleek-modeline-diagnostics nil t)
	  (sleek-modeline-diagnostics-enable))

	;; Enable project segment if configured
	(when sleek-modeline-enable-project
	  (require 'sleek-modeline-project nil t))

	;; Enable LSP segment if configured
	(when sleek-modeline-enable-lsp
	  (require 'sleek-modeline-lsp nil t)
	  (sleek-modeline-lsp-enable))

	;; Update faces now if a real (non-daemon-initial) frame exists;
	;; otherwise defer the first update until a client frame shows up.
	;; This fixes the startup-in-daemon-mode colour bug where faces were
	;; computed against the daemon's initial frame (whose `default'
	;; background is unthemed), producing a too-bright modeline until
	;; the server was restarted.
	(if (sleek-modeline--graphical-frame-exists-p)
	    (sleek-modeline--update-faces)
	  (add-hook 'server-after-make-frame-hook
		    #'sleek-modeline--deferred-face-update)
	  (add-hook 'after-make-frame-functions
		    #'sleek-modeline--deferred-face-update)))

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
    (remove-hook 'server-after-make-frame-hook
                 #'sleek-modeline--deferred-face-update)
    (remove-hook 'after-make-frame-functions
                 #'sleek-modeline--deferred-face-update)
    (advice-remove 'load-theme #'sleek-modeline--after-theme-change)
    (advice-remove 'enable-theme #'sleek-modeline--after-theme-change)

    ;; Disable vc segment cache hooks
    (sleek-modeline-vc-disable)

    ;; Disable diagnostics segment if enabled
    (when sleek-modeline-enable-diagnostics
      (sleek-modeline-diagnostics-disable))

    ;; Disable LSP segment if enabled
    (when sleek-modeline-enable-lsp
      (sleek-modeline-lsp-disable)))

  (force-mode-line-update t))

(provide 'sleek-modeline)
;;; sleek-modeline.el ends here
