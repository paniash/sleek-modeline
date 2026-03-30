;;; sleek-modeline-core.el --- Helper functions for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Core functionality for the `sleek-modeline' package.  That includes functions,
;; customizable variables and face definitions.

;;; Code:

(require 'color)
(require 'cl-lib)

;; NOTE(abi): optional dependency; only gets loaded if available.
(declare-function nerd-icons-icon-for-file "nerd-icons")

(defgroup sleek-modeline nil
  "Customization group for `sleek-modeline'."
  :group 'mode-line
  :prefix "sleek-modeline-")

(defgroup sleek-modeline-faces nil
  "Customization group for faces used by `sleek-modeline'."
  :group 'sleek-modeline
  :group 'faces)

(defcustom sleek-modeline-size 'small
  "Size of the mode-line.
This affects the visual height through the box property."
  :type '(choice
          (const :tag "small" small)
          (const :tag "medium" medium)
          (const :tag "large" large))
  :group 'sleek-modeline
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Only update if mode is currently active
         (when (and (boundp 'sleek-modeline-mode)
                    sleek-modeline-mode)
           (sleek-modeline--update-faces))))

(defcustom sleek-modeline-height nil
  "Custom height for the mode-line box property.
When nil, uses the value determined by `sleek-modeline-size'.
When set to a number, overrides the size setting."
  :type '(choice (const :tag "Use size setting" nil)
                 (integer :tag "Custom height"))
  :group 'sleek-modeline
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Only update if mode is currently active
         (when (and (boundp 'sleek-modeline-mode)
                    sleek-modeline-mode)
           (sleek-modeline--update-faces))))

(defcustom sleek-modeline-show-icons t
  "Whether to show nerd icons in the modeline.
Requires `nerd-icons' package to be installed."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-highlight-modified-buffer-name t
  "Whether to highlight the buffer name when it has unsaved changes.
When non-nil, modified buffers will use
`sleek-modeline-buffer-name-modified-face'."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-show-modal-state nil
  "Whether to show modal editing state (Evil/Meow) marker."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-modal-inactive nil
  "Hide modal state marker in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-separator " » "
  "Separator string used between segments in the mode-line."
  :type 'string
  :group 'sleek-modeline)

(defface sleek-modeline-buffer-name-face
  '((t (:inherit mode-line-buffer-id :weight bold)))
  "Face for buffer name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-buffer-name-modified-face
  '((t (:inherit warning :weight bold)))
  "Face for modified buffer name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-major-mode-face
  '((t (:inherit font-lock-function-name-face :weight bold :slant normal)))
  "Face for major mode in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defcustom sleek-modeline-background nil
  "Custom background for the mode-line.
If nil, derives from `default` face."
  :type '(choice (const :tag "Derive from default" nil)
                 color)
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-file-icon-inactive nil
  "Hide the file icon in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-major-mode-inactive nil
  "Hide the major mode name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-line-ending-inactive nil
  "Hide the line ending style in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-modal-normal-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#89b4fa")))
  "Face for normal modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-insert-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#a6e3a1")))
  "Face for insert modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-visual-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#cba6f7")))
  "Face for visual modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-other-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#f38ba8")))
  "Face for other modal states." :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-face
  '((t (:inherit font-lock-comment-face :weight bold :slant italic)))
  "Face for version control info in `sleek-modeline'.
Used when the repository is in a clean state."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-modified-face
  '((t (:inherit font-lock-variable-name-face :weight bold :slant italic)))
  "Face for version control info when there are modifications.
Used for edited, added, or needs-update states."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-conflict-face
  '((t (:inherit error)))
  "Face for version control info when there are conflicts.
Used for removed, conflict, unregistered, or needs-merge states."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-line-ending-face
  '((t (:inherit font-lock-doc-face :slant normal)))
  "Face for the line ending indicator in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-separator-face
  '((t (:inherit shadow)))
  "Face for the separator between segments in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-buffer-name ()
  "Show buffer name with custom face and optional icon (if available).
Change color when buffer is modified and dim or hide components when
the mode-line is inactive according to configuration."
  (let* ((file-name (buffer-file-name))
         (icon (when (and sleek-modeline-show-icons
                          file-name
                          (featurep 'nerd-icons))
                 (nerd-icons-icon-for-file file-name)))
         (buffer-name (substring-no-properties (format-mode-line "%b")))
         (face (if (and sleek-modeline-highlight-modified-buffer-name
                        (buffer-modified-p))
                   'sleek-modeline-buffer-name-modified-face
                 'sleek-modeline-buffer-name-face))
         (icon (sleek-modeline--maybe-dim-or-hide
                icon
                sleek-modeline-hide-file-icon-inactive))
         (buffer-name (sleek-modeline--maybe-dim-or-hide
                       (propertize buffer-name 'face face) nil)))
    (if icon (concat icon " " buffer-name) buffer-name)))

(defun sleek-modeline-major-mode ()
  "Show major mode with custom face, stripping mode-line suffix indicators.
Optionally dim or hide in inactive mode-lines."
  (let ((name (replace-regexp-in-string
               "/.*\\'" ""
               (substring-no-properties (format-mode-line mode-name)))))
    (sleek-modeline--maybe-dim-or-hide
     (propertize name 'face 'sleek-modeline-major-mode-face)
     sleek-modeline-hide-major-mode-inactive)))

(defun sleek-modeline--modal-state ()
  "Return the current modal editing state as a single letter, or nil.
Checks `evil-mode' first, then `meow-mode'.  Returns nil if neither is active."
  (when sleek-modeline-show-modal-state
    (cond
     ((and (featurep 'evil)
           (bound-and-true-p evil-local-mode)
           (boundp 'evil-state))
      (pcase evil-state
        ('normal "N")
        ('insert "I")
        ('visual "V")
        ('replace "R")
        ('operator "O")
        ('motion "M")
        ('emacs "E")
        (_ "?")))
     ((and (featurep 'meow)
           (bound-and-true-p meow-mode)
           (boundp 'meow--current-state))
      (pcase meow--current-state
        ('normal "N")
        ('insert "I")
        ('keypad "K")
        ('motion "M")
        ('beacon "B")
        (_ "?")))
     (t nil))))

(defun sleek-modeline-modal-state-marker ()
  "Return a propertized, modal state marker with state-dependent background."
  (when-let ((state (sleek-modeline--modal-state)))
    (let* ((base-face (pcase state
                        ("N" 'sleek-modeline-modal-normal-face)
                        ("I" 'sleek-modeline-modal-insert-face)
                        ("V" 'sleek-modeline-modal-visual-face)
                        (_   'sleek-modeline-modal-other-face)))
           (face (if (sleek-modeline--inactive-p)
                     (sleek-modeline--dim-background base-face)
                   base-face)))
      (propertize (format " %s " state) 'face face))))

(defun sleek-modeline--get-height ()
  "Get mode-line height based on `sleek-modeline-size' or `sleek-modeline-height'.
Returns the box line-width value to use for the mode-line."
  (or sleek-modeline-height
      (pcase sleek-modeline-size
        ('small 1)
        ('medium 5)
        ('large 10))))

(defun sleek-modeline--update-faces ()
  "Update mode-line face attributes based on current height settings.
Derives mode-line backgrounds by darkening the current `default' face,
ensuring the modeline is always visually distinct from buffer content."
  (let* ((modeline-height (sleek-modeline--get-height))
         ;; NOTE(abi): `face-background' can return nil or unspecified-bg on terminal
         ;; frames or before a theme has set the default face.  We filter those out so
         ;; that colour blending functions never receive unparsable input.
         (raw-background (or sleek-modeline-background
                             (face-background 'default nil t)))
         (default-background (if (sleek-modeline--valid-color-p raw-background)
                                 raw-background
                               "#000000"))
         (modeline-background (sleek-modeline--darken default-background 0.30))
         (modeline-inactive-background (sleek-modeline--darken default-background 0.15)))
    (when (facep 'mode-line)
      (set-face-attribute 'mode-line nil
                          :background modeline-background
                          :box `(:line-width ,modeline-height :color ,modeline-background)
                          :underline nil))
    (when (facep 'mode-line-inactive)
      (set-face-attribute 'mode-line-inactive nil
                          :background modeline-inactive-background
                          :box `(:line-width ,modeline-height :color ,modeline-inactive-background)
                          :underline nil))
    (sleek-modeline--update-separator-face)
    (force-mode-line-update t)))

(defun sleek-modeline--line-ending ()
  "Return a string describing the buffer's line ending convention."
  (pcase (coding-system-eol-type buffer-file-coding-system)
    (0 "LF")
    (1 "CRLF")
    (2 "CR")
    (_ "—")))

(defun sleek-modeline-line-ending-indicator ()
  "Return a propertized line ending string, or empty string for non-file buffers.
Dim or hide in inactive mode-lines according to configuration."
  (if buffer-file-name
      (sleek-modeline--maybe-dim-or-hide
       (propertize (sleek-modeline--line-ending)
                   'face 'sleek-modeline-line-ending-face
                   'help-echo "Buffer line endings")
       sleek-modeline-hide-line-ending-inactive)
    ""))

(defun sleek-modeline--separator ()
  "Return the propertized segment separator."
  (propertize sleek-modeline-separator 'face 'sleek-modeline-separator-face))

(defun sleek-modeline--inactive-p ()
  "Return non-nil if the current mode-line is inactive."
  (not (mode-line-window-selected-p)))

(defun sleek-modeline--dim (str)
  "Return STR with an inactive/dimmed face."
  (propertize str 'face 'mode-line-inactive))
;;(add-face-text-property 0 (length str) 'mode-line-inactive 'append str))

(defun sleek-modeline--dim-background (face)
  "Return a dimmed version of FACE by blending its background."
  (let* ((bg (face-background face nil t))
         (inactive-bg (face-background 'mode-line-inactive nil t))
         (dimmed-bg (if (and bg inactive-bg)
                        (sleek-modeline--blend-colors bg inactive-bg 0.5)
                      inactive-bg)))
    `(:inherit ,face :background ,dimmed-bg)))

(defun sleek-modeline--dim-icon (icon)
  "Return ICON dimmed for inactive mode-line while preserving its foreground."
  (let* ((bg (face-background 'mode-line-inactive nil t))
         ;; derive a temporary face with blended background
         (dim-face (make-face 'sleek-modeline-temp-dim-face)))
    (set-face-attribute dim-face nil
                        :inherit (or (get-text-property 0 'face icon) 'default)
                        :background bg)
    (propertize icon 'face dim-face)))

(defun sleek-modeline--maybe-dim-or-hide (str hide-inactive)
  "Return STR, dimmed or hidden if inactive.
If HIDE-INACTIVE is non-nil, return nil when inactive."
  (cond
   ((not str) nil)
   ((sleek-modeline--inactive-p)
    (unless hide-inactive
      (sleek-modeline--dim str)))
   (t str)))

(defun sleek-modeline--valid-color-p (color)
  "Return non-nil if COLOR is a string that `color-name-to-rgb' can parse."
  (and (stringp color)
       (not (string-prefix-p "unspecified" color))
       (color-name-to-rgb color)))

(defun sleek-modeline--blend-colors (c1 c2 alpha)
  "Blend C1 toward C2 by ALPHA (0.0 = C2, 1.0 = C1).
Returns C1 unchanged when either color cannot be parsed."
  (let ((rgb1 (and (stringp c1) (color-name-to-rgb c1)))
        (rgb2 (and (stringp c2) (color-name-to-rgb c2))))
    (if (and rgb1 rgb2)
        (apply #'color-rgb-to-hex
               (cl-mapcar (lambda (a b) (+ (* alpha a) (* (- 1.0 alpha) b)))
                          rgb1 rgb2))
      (or c1 c2))))

(defun sleek-modeline--darken (color amount)
  "Darken COLOR by AMOUNT (0.0 = unchanged, 1.0 = black)."
  (sleek-modeline--blend-colors color "#000000" (- 1.0 amount)))

(defun sleek-modeline--update-separator-face ()
  "Set separator face to a dimmed version of the shadow face foreground."
  (let ((shadow-fg (face-foreground 'shadow nil t))
        (bg (face-background 'default nil t)))
    (when (and shadow-fg bg)
      (set-face-attribute 'sleek-modeline-separator-face nil
                          :foreground (sleek-modeline--blend-colors shadow-fg bg 0.5)))))

(provide 'sleek-modeline-core)
;;; sleek-modeline-core.el ends here
