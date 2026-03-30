;;; sleek-modeline-project.el --- Project segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Project name segment for the `sleek-modeline' package.
;; Supports both `projectile' and the built-in `project.el' backends,
;; preferring projectile when both are active.

;;; Code:

(require 'sleek-modeline-core)

;; Optional dependencies, declared to silence the byte-compiler.
(eval-when-compile
  (declare-function projectile-project-name "projectile")
  (declare-function project-current "project")
  (declare-function project-root "project")
  (defvar projectile-mode))

(defcustom sleek-modeline-hide-project-name-inactive nil
  "Hide project name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-project-face
  '((t (:inherit font-lock-string-face :weight bold :slant normal)))
  "Face for the project name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-project--name ()
  "Return the current project name string, or nil if not in a project.
Prefers `projectile' when active, falls back to `project.el'."
  (cond
   ;; `projectile' backend
   ;; NOTE(abi): sentinel value \"-\" means no project.
   ((and (featurep 'projectile)
         (bound-and-true-p projectile-mode))
    (let ((name (projectile-project-name)))
      (unless (string= name "-")
        name)))

   ;; `project.el' backend
   ((featurep 'project)
    (when-let* ((proj (project-current))
                (root (project-root proj)))
      (file-name-nondirectory (directory-file-name root))))))

(defun sleek-modeline-project ()
  "Return the propertized project name for the mode-line, or nil."
  (condition-case nil
      (when-let ((name (sleek-modeline-project--name)))
	(sleek-modeline--maybe-dim-or-hide
	 (propertize name 'face 'sleek-modeline-project-face)
	 sleek-modeline-hide-project-name-inactive))
    (error nil)))

(provide 'sleek-modeline-project)
;;; sleek-modeline-project.el ends here
