;;; sleek-modeline-helpers.el --- Helper functions for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Helper functions for the `sleek-modeline' package.

;;; Code:

(require 'sleek-modeline-faces)

;; NOTE(abi): optional dependency; only gets loaded if available.
(declare-function nerd-icons-icon-for-file "nerd-icons")

(defcustom sleek-modeline-show-icons t
  "Whether to show nerd icons in the modeline.
Requires `nerd-icons' package to be installed."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-highlight-modified-buffer-name t
  "Whether to highlight the buffer name when it has unsaved changes.
When non-nil, modified buffers will use `sleek-modeline-buffer-name-modified-face'."
  :type 'boolean
  :group 'sleek-modeline)

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

(provide 'sleek-modeline-helpers)

;;; sleek-modeline-helpers.el ends here
