;;; sleek-modeline-helpers.el --- Helper functions for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Core functionality for the `sleek-modeline' package.  That includes functions,
;; customizable variables and face definitions.

;;; Code:

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
When non-nil, modified buffers will use the `sleek-modeline-buffer-name-modified-face'."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-show-modal-state nil
  "Whether to show modal editing state (Evil/Meow) marker."
  :type 'boolean
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
  '((t (:inherit font-lock-doc-face :slant italic)))
  "Face for major mode in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-face
  '((t (:inherit font-lock-comment-face)))
  "Face for version control info in `sleek-modeline'.
Used when the repository is in a clean state."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-modified-face
  '((t (:inherit font-lock-variable-name-face)))
  "Face for version control info when there are modifications.
Used for edited, added, or needs-update states."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-conflict-face
  '((t (:inherit error)))
  "Face for version control info when there are conflicts.
Used for removed, conflict, unregistered, or needs-merge states."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-buffer-name ()
  "Show buffer name with custom face and icon (if available).
Changes color when buffer is modified."
  (let* ((file-name (buffer-file-name))
         (icon (when (and sleek-modeline-show-icons
                          file-name
                          (featurep 'nerd-icons))
                 (nerd-icons-icon-for-file file-name)))
         (buffer-name (substring-no-properties (format-mode-line "%b")))
	 ;; Use modified face if buffer has unsaved changes
	 (face (if (and sleek-modeline-highlight-modified-buffer-name
			(buffer-modified-p))
		   'sleek-modeline-buffer-name-modified-face
		 'sleek-modeline-buffer-name-face)))
    (if icon
        (concat icon " " (propertize buffer-name 'face face))
      (propertize buffer-name 'face face))))

(defun sleek-modeline-major-mode ()
  "Show major mode with custom face."
  (propertize (substring-no-properties (format-mode-line mode-name))
              'face 'sleek-modeline-major-mode-face))

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
  "Return formatted modal state marker like '<N> ' or an empty string."
  (let ((state (sleek-modeline--modal-state)))
    (if state
        (format "<%s> " state)
      "")))

(defun sleek-modeline--get-height ()
  "Get mode-line height based on `sleek-modeline-size' or `sleek-modeline-height'.
Returns the box line-width value to use for the mode-line."
  (or sleek-modeline-height
      (pcase sleek-modeline-size
        ('small 1)
        ('medium 5)
        ('large 10))))

(defun sleek-modeline--update-faces ()
  "Update mode-line face attributes based on current height settings."
  (let ((height (sleek-modeline--get-height)))
    (when (facep 'mode-line)
      (let ((bg (or (face-background 'mode-line nil t)
                    (face-background 'default nil t)
                    "black")))
        (set-face-attribute 'mode-line nil
                            :box `(:line-width ,height :color ,bg)
                            :underline nil)))
    (when (facep 'mode-line-inactive)
      (let ((bg (or (face-background 'mode-line-inactive nil t)
                    (face-background 'mode-line nil t)
                    (face-background 'default nil t)
                    "black")))
        (set-face-attribute 'mode-line-inactive nil
                            :box `(:line-width ,height :color ,bg)
                            :underline nil)))
    ;; Force redisplay
    (force-mode-line-update t)))

(provide 'sleek-modeline-core)

;;; sleek-modeline-core.el ends here
