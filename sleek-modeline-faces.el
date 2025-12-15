;;; sleek-modeline-faces.el --- Face definitions for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Face definitions for the `sleek-modeline' package.

;;; Code:

(defgroup sleek-modeline nil
  "Customization group for `sleek-modeline'."
  :group 'mode-line
  :prefix "sleek-modeline-")

(defgroup sleek-modeline-faces nil
  "Customization group for faces used by `sleek-modeline'."
  :group 'sleek-modeline
  :group 'faces)

(defface sleek-modeline-buffer-name-face
  '((t (:inherit mode-line-buffer-id :weight bold)))
  "Face for buffer name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-major-mode-face
  '((t (:inherit font-lock-doc-face :slant italic)))
  "Face for major mode in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(provide 'sleek-modeline-faces)

;;; sleek-modeline-faces.el ends here
