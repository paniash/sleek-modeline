;;; sleek-modeline-vc.el --- Version control segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Version control segment for the `sleek-modeline' package.
;; Displays the current branch name and optionally a branch icon.

;;; Code:

(require 'vc)
(require 'sleek-modeline-core)

;; NOTE(abi): optional dependency; only gets loaded if available.
(declare-function nerd-icons-octicon "nerd-icons")

(defcustom sleek-modeline-vc-show-icon t
  "Whether to show the branch icon in the version control segment.
Requires `nerd-icons' package to be installed."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-vc-use-github-icon nil
  "Whether to use the GitHub icon instead of the git branch icon.
When non-nil, shows the GitHub mark icon.
When nil, shows the git branch icon."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-vc-icon-inactive nil
  "Hide version control icon in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-vc-branch-inactive nil
  "Hide the version control branch name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defun sleek-modeline-vc--branch-icon ()
  "Return the appropriate branch icon based on configuration.
Returns empty string if icons are disabled, nerd-icons is not available,
or if hidden due to inactive mode-line."
  (when (and sleek-modeline-vc-show-icon
             sleek-modeline-show-icons
             (featurep 'nerd-icons))
    (let ((icon (if sleek-modeline-vc-use-github-icon
                    (nerd-icons-octicon "nf-oct-mark_github")
                  (nerd-icons-octicon "nf-oct-git_branch"))))
      (sleek-modeline--maybe-dim-or-hide icon sleek-modeline-hide-vc-icon-inactive))))

(defun sleek-modeline-vc--branch-name ()
  "Get the current branch name from `vc-mode'.
Returns nil if not in a version-controlled file."
  (when (and vc-mode (stringp vc-mode) buffer-file-name)
    (when (string-match "^ [A-Za-z]+[:-]\\(.*\\)" vc-mode)
      (let ((branch (string-trim (substring-no-properties (match-string 1 vc-mode)))))
        (unless (string-empty-p branch)
          branch)))))

(defun sleek-modeline-vc--state-face ()
  "Return the appropriate face based on VC state.
Uses different faces for modified, conflict, and clean states."
  (if-let* ((file buffer-file-name)
            (state (vc-state file)))
      (cond
       ((memq state '(edited added)) 'sleek-modeline-vc-modified-face)
       ((memq state '(removed conflict unregistered)) 'sleek-modeline-vc-conflict-face)
       ((eq state 'needs-merge) 'sleek-modeline-vc-conflict-face)
       ((eq state 'needs-update) 'sleek-modeline-vc-modified-face)
       (t 'sleek-modeline-vc-face))
    'sleek-modeline-vc-face))

(defun sleek-modeline-vc ()
  "Show version control information with icon and branch name.
Returns nil if not in a version-controlled file or if an error occurs."
  (condition-case nil
      (when-let ((branch (sleek-modeline-vc--branch-name)))
        (let* ((icon (sleek-modeline-vc--branch-icon))
               (face (sleek-modeline-vc--state-face))
               (branch-str (propertize branch 'face face)))
          (sleek-modeline--maybe-dim-or-hide
           (if icon
               (concat icon " " branch-str)
             branch-str)
           sleek-modeline-hide-vc-branch-inactive)))
    (error nil)))

(provide 'sleek-modeline-vc)
;;; sleek-modeline-vc.el ends here
