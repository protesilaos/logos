;;; logos.el --- Simple focus mode and extras -*- lexical-binding: t -*-

;; Copyright (C) 2022-2023  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Logos Development <~protesilaos/logos@lists.sr.ht>
;; URL: https://git.sr.ht/~protesilaos/logos
;; Mailing-List: https://lists.sr.ht/~protesilaos/logos
;; Version: 1.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, focus, writing, presentation, narrowing

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package provides a simple "focus mode" which can be applied to any
;; buffer for reading, writing, or even doing a presentation.  The buffer
;; can be divided in pages using the `page-delimiter', outline structure,
;; or any other pattern.  Commands are provided to move between those
;; pages.  These motions work even when narrowing is in effect (and they
;; preserve it).  `logos.el' is designed to be simple by default and easy
;; to extend.  This manual provides concrete examples to that end.
;;
;; What constitutes a page delimiter is determined by the user options
;; `logos-outlines-are-pages' and `logos-outline-regexp-alist'.  By
;; default, this only corresponds to the `^L' character (which can be
;; inserted using the standard keys with `C-q C-l').
;;
;; Logos does not define any key bindings.  Try something like this, if you
;; want:
;;
;;     (let ((map global-map))
;;       (define-key map [remap narrow-to-region] #'logos-narrow-dwim)
;;       (define-key map [remap forward-page] #'logos-forward-page-dwim)
;;       (define-key map [remap backward-page] #'logos-backward-page-dwim))
;;
;; On standard Emacs, those key bindings are: `C-x n n', `C-x ]', `C-x ['.
;; The `logos-narrow-dwim' is not necessary for users who already know how
;; to narrow effectively.  Such users may still want to bind it to a key.
;;
;; For users running Emacs version 28 or higher, Logos defines the
;; `logos-repeat-map' which is activated when `repeat-mode' is enabled.
;; This means that page motions, `C-x ]' and `C-x [', can be repeated by
;; following them up with `]' and `[', respectively.  The repetition stops
;; when another command is invoked.
;;
;; Logos provides some optional aesthetic tweaks which come into effect
;; when the buffer-local `logos-focus-mode' is enabled.  These will hide
;; the cursor (`logos-hide-cursor'), hide the mode line
;; (`logos-hide-mode-line'), disable the buffer boundary indicators
;; (`indicate-buffer-boundaries'), enable `scroll-lock-mode'
;; (`logos-scroll-lock'), use `variable-pitch-mode' in non-programming
;; buffers (`logos-variable-pitch'), make the buffer read-only
;; (`logos-buffer-read-only'), center the buffer in its window if the
;; `olivetti' package is installed (`logos-olivetti'), and hide the
;; `fringe' face (`logos-hide-fringe').  All these variables are
;; buffer-local.
;;
;; Furthermore, the `logos-focus-mode' establishes a bespoke keymap, which
;; can be used to, for example, bind the arrow keys to page motions.  The
;; keymap is `logos-focus-mode-map' and is empty by default (we do not
;; define any keys and trust the user to pick their own).
;;
;; Logos is the familiar word derived from Greek (watch my presentation on
;; philosophy about Cosmos, Logos, and the living universe:
;; <https://protesilaos.com/books/2022-02-05-cosmos-logos-living-universe/>),
;; though it also stands for these two perhaps equally insightful
;; backronyms about the mechanics of this package:
;;
;; 1. `^L' Only Generates Ostensible Slides
;; 2. Logos Optionally Goes through Outline Sections
;;
;;
;; Consult the manual for all sorts of tweaks and extras:
;; <https://protesilaos.com/emacs/logos>.

;;; Code:

;;;; General utilities

(defgroup logos ()
  "Simple focus mode and extras."
  :group 'editing)

(defcustom logos-outlines-are-pages nil
  "When non-nil, every outline heading is a page delimiter.
What constitutes an outline is determined by the user option
`logos-outline-regexp-alist'.

When this variable is nil, pages are demarcated by the
`page-delimiter'."
  :type 'boolean
  :package-version '(logos . "0.1.0")
  :group 'logos)

(defcustom logos-outline-regexp-alist
  `((emacs-lisp-mode . "^;;;+ ")
    (org-mode . "^\\*+ +")
    (markdown-mode . "^\\#+ +"))
  "Alist of major mode and regular expression of the outline.
Only used when `logos-outlines-are-pages' is non-nil.

The major mode also targets any of its derivatives.  For example,
`lisp-interaction-mode' (the standard scratch buffer) is based on
`emacs-lisp-mode' so one only needs to set the outline regexp of
the latter.

If the current buffer's major mode is not specified herein, Logos
will try to use the `outline-regexp', else fall back to the
generic `page-delimiter'."
  :type `(alist :key-type symbol :value-type string) ; TODO 2022-03-02: ensure symbol is mode?
  :package-version '(logos . "1.0.0")
  :group 'logos)

(defcustom logos-hide-cursor nil
  "When non-nil hide the cursor.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "1.0.0")
  :local t)

(defcustom logos-hide-mode-line nil
  "When non-nil hide the modeline.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.1.0")
  :local t)

(defcustom logos-scroll-lock nil
  "When non-nil, use `scroll-lock-mode'.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.1.0")
  :local t)

(defcustom logos-variable-pitch nil
  "When non-nil, use `variable-pitch-mode' where appropriate.
In programming modes the default font is always used, as that is
assumed to be a monospaced typeface, which is appropriate for
spacing-sensitive text.

This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.5.0")
  :local t)

(define-obsolete-variable-alias
  'logos-indicate-buffer-boundaries
  'logos-hide-buffer-boundaries
  "0.4.0")

(defcustom logos-hide-buffer-boundaries nil
  "If non-nil locally disable `indicate-buffer-boundaries'.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.4.0")
  :local t)

(defcustom logos-buffer-read-only nil
  "If non-nil make buffer read-only.
This applies when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.2.0")
  :local t)

(defcustom logos-olivetti nil
  "If non-nil center buffer in its window with Olivetti package.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.2.0")
  :local t)

(defcustom logos-hide-fringe nil
  "If non-nil make the `fringe' face the same as `default' background.
This is only relevant when `logos-focus-mode' is enabled."
  :type 'boolean
  :group 'logos
  :package-version '(logos . "0.4.0")
  :local t)

(define-obsolete-variable-alias
  'logos-focus-mode-extra-functions
  'logos-focus-mode-hook
  "1.1.0")

(defcustom logos-focus-mode-hook nil
  "List of functions to execute when `logos-focus-mode' is enabled.

Each function is called without an argument.  An example that
sets a variable is `logos--buffer-read-only'; one that sets a
mode is `logos--scroll-lock'; another that sets the mode of an
external package is `logos--olivetti'; while `logos--hide-fringe'
provides yet another useful sample.

Consult the Logos manual for concrete do-it-yourself examples.

If a function cannot be like the aforementioned though still
needs to set its state both when `logos-focus-mode' is enabled
and disabled, then use the `logos-focus-mode-hook' instead."
  :type 'hook
  :package-version '(logos . "0.4.0")
  :group 'logos)

;;;; General utilities

(defun logos--focus-p ()
  "Return non-nil if `logos-focus-mode' is bound locally."
  (when (bound-and-true-p logos-focus-mode)
    (buffer-local-value 'logos-focus-mode (current-buffer))))

;;;; Page motions

(define-obsolete-variable-alias
  'logos--page-delimiter
  'logos-page-delimiter
  "1.1.0")

(defconst logos-page-delimiter (default-value 'page-delimiter)
  "The default value of `page-delimiter'.")

(defun logos--outline-or-delimiter ()
  "Return the current `outline-regexp' or page delimiter."
  (if (bound-and-true-p outline-regexp)
      outline-regexp
    logos-page-delimiter))

(defun logos--outline-regexp ()
  "Return page delimiter from `logos-outline-regexp-alist'."
  (let ((outline logos-outline-regexp-alist)
        (mode major-mode))
    (or (alist-get mode outline)
        (alist-get (get mode 'derived-mode-parent) outline)
        (logos--outline-or-delimiter))))

(define-obsolete-function-alias
  'logos--page-delimiter
  'logos-page-delimiter
  "1.1.0")

(defun logos-page-delimiter ()
  "Determine the `page-delimiter'."
  (if logos-outlines-are-pages
      (setq-local page-delimiter (logos--outline-regexp))
    (setq-local page-delimiter logos-page-delimiter)))

(defun logos--narrow-to-page (count &optional back)
  "Narrow to COUNTth page with optional BACK motion."
  ;; Position point to avoid skipping pages.
  (when (and (buffer-narrowed-p)
             (save-restriction
               (widen)
               (looking-at page-delimiter)))
    (goto-char (if back
                   (1+ (match-end 0))
                 (1- (match-beginning 0)))))
  (if back
      (narrow-to-page (or (- count) -1))
    (narrow-to-page (or (abs count) 1)))
  (let ((page-start (point-min-marker)))
    ;; If outlines are pages, include match of page-delimiter in page
    (when (and logos-outlines-are-pages
               (save-excursion
                 (goto-char (point-min))
                 (save-restriction
                   (widen)
                   (looking-back page-delimiter (line-beginning-position)))))
      (let ((match-start (match-beginning 0))
            (page-end (point-max-marker)))
        (widen)
        (narrow-to-region match-start page-end)))
    ;; Leave point at a standard location: if outlines are pages,
    ;; leave it right after the page-delimiter (to match the
    ;; unnarrowed behavior); if outlines are not pages, leave it at
    ;; the beginning of the page.
    (goto-char page-start)))

(defvar logos-page-motion-hook nil
  "Hook that runs after a page motion.
See `logos-forward-page-dwim' or `logos-backward-page-dwim'.")

(defun logos--page-motion (&optional count back)
  "Routine for page motions.
With optional numeric COUNT move by that many pages.  With
optional BACK perform the motion backwards."
  (let ((cmd (if back #'backward-page #'forward-page)))
    (logos-page-delimiter)
    (if (buffer-narrowed-p)
        (logos--narrow-to-page count back)
      (funcall cmd count)
      (setq this-command cmd))
    (run-hooks 'logos-page-motion-hook)))

;;;###autoload
(defun logos-forward-page-dwim (&optional count)
  "Move to next or COUNTth page forward.
If the buffer is narrowed, keep the effect while performing the
motion.  Always move point to the beginning of the narrowed
page."
  (interactive "p")
  (logos--page-motion count))

;;;###autoload
(defun logos-backward-page-dwim (&optional count)
  "Move to previous or COUNTth page backward.
If the buffer is narrowed, keep the effect while performing the
motion.  Always move point to the beginning of the narrowed
page."
  (interactive "p")
  (logos--page-motion count :back))

(declare-function org-at-heading-p "org" (&optional _))
(declare-function org-show-entry "org")
(declare-function outline-on-heading-p "outline" (&optional invisible-ok))
(declare-function outline-show-entry "outline")

(defun logos--reveal-entry ()
  "Reveal Org or Outline entry."
  (cond
   ((and (eq major-mode 'org-mode)
         (org-at-heading-p))
    (org-show-entry))
   ((and (or (eq major-mode 'outline-mode)
             (bound-and-true-p outline-minor-mode))
         (outline-on-heading-p))
    (outline-show-entry))))

(add-hook 'logos-page-motion-hook #'logos--reveal-entry)

;;;; Narrowing
;; NOTE 2022-03-02: This section is most likely unnecessary, but let's
;; keep it for now.

(defun logos--window-bounds ()
  "Determine start and end points in the window."
  (list (window-start) (window-end)))

(defun logos--page-p ()
  "Return non-nil if there is a `page-delimiter' in the buffer.
This function does not use `widen': it only checks the accessible
portion of the buffer."
  (let ((delimiter (logos-page-delimiter)))
    (or (save-excursion (re-search-forward delimiter nil t))
        (save-excursion (re-search-backward delimiter nil t)))))

(defun logos-narrow-visible-window ()
  "Narrow buffer to visible window area.
Also check `logos-narrow-dwim'."
  (interactive)
  (let* ((bounds (logos--window-bounds))
         (window-area (- (cadr bounds) (car bounds)))
         (buffer-area (- (point-max) (point-min))))
    (if (/= buffer-area window-area)
        (narrow-to-region (car bounds) (cadr bounds))
      (user-error "Buffer fits in the window; won't narrow"))))

;;;###autoload
(defun logos-narrow-dwim ()
  "Do-what-I-mean narrowing.

If region is active, narrow the buffer to the region's
boundaries.

If pages are defined by virtue of `logos--page-p', narrow to
the current page boundaries.

If no region is active and no pages exist, narrow to the visible
portion of the window.

If narrowing is in effect, widen the view."
  (interactive)
  (unless mark-ring                  ; needed when entering a new buffer
    (push-mark (point) t nil))
  (cond
   ((and (use-region-p)
         (null (buffer-narrowed-p)))
    (narrow-to-region (region-beginning) (region-end)))
   ((logos--page-p)
    ;; Use our own narrow to page function because when
    ;; logos-outlines-are-pages is t, the page delimiter
    ;; is included in the region narrowed to.
    (logos--narrow-to-page 0))
   ((null (buffer-narrowed-p))
    (logos-narrow-visible-window))
   ((widen))))

;;;; Optional "focus mode" and utilities

;; I learnt about the method of using `logos-set-mode-arg' and
;; `logos-set-buffer-local-value' from Daniel Mendler:
;; <https://github.com/minad>.
(defvar-local logos--restore nil)

(define-obsolete-function-alias
  'logos--mode
  'logos-set-mode-arg
  "1.1.0")

(defun logos-set-mode-arg (mode arg)
  "Set MODE to ARG.
ARG is either 1 or -1.  The current value changes to its
alternate, thus toggling MODE."
  (let ((old (if (and (boundp mode) (symbol-value mode)) 1 -1)))
    (unless (eq old arg)
      (push (lambda () (funcall mode old)) logos--restore)
      (funcall mode arg))))

(define-obsolete-function-alias
  'logos--set
  'logos-set-buffer-local-value
  "1.1.0")

(defun logos-set-buffer-local-value (var val)
  "Set VAR to buffer-local VAL."
  (let ((old (and (boundp var) (symbol-value var))))
    (unless (equal old val)
      (set var val)
      (if (local-variable-p var)
          (push (lambda () (set var old)) logos--restore)
        (make-local-variable var)
        (push (lambda () (kill-local-variable var)) logos--restore)))))

(defvar logos-focus-mode-map (make-sparse-keymap)
  "The keymap of `logos-focus-mode'.")

(defvar logos-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map "]" 'logos-forward-page-dwim)
    (define-key map "[" 'logos-backward-page-dwim)
    map)
  "Keymap to repeat logos key sequences.  Used in `repeat-mode'.")

(put #'logos-forward-page-dwim 'repeat-map 'logos-repeat-map)
(put #'logos-backward-page-dwim 'repeat-map 'logos-repeat-map)

;;;###autoload
(define-minor-mode logos-focus-mode
  "Buffer-local mode for focused editing.
When enabled it sets the buffer-local value of these user
options: `logos-scroll-lock', `logos-variable-pitch',
`logos-hide-cursor', `logos-hide-mode-line',
`logos-hide-buffer-boundaries', `logos-buffer-read-only',
`logos-olivetti', `logos-hide-fringe'."
  :init-value nil
  :global nil
  :keymap logos-focus-mode-map
  :lighter " Λ" ; lambda majuscule
  (mapc #'funcall logos--restore)
  (logos--remove-fringe-remap)
  (setq logos--restore nil)
  (when logos-focus-mode
    (logos--setup)
    (run-hooks 'logos-focus-mode-hook)))

(defun logos--setup ()
  "Set up aesthetics for presentation."
  ;; modes
  (logos--variable-pitch)
  (logos--scroll-lock)
  (logos--olivetti)
  ;; variables
  (logos--hide-cursor)
  (logos--hide-mode-line)
  (logos--indicate-buffer-boundaries)
  (logos--buffer-read-only)
  ;; faces
  (logos--hide-fringe))

(defun logos--variable-pitch ()
  "Set `logos-variable-pitch'."
  (when (and logos-variable-pitch (not (derived-mode-p 'prog-mode)))
    (logos-set-mode-arg 'variable-pitch-mode 1)))

(defun logos--scroll-lock ()
  "Set `logos-scroll-lock'."
  (when logos-scroll-lock
    (logos-set-mode-arg 'scroll-lock-mode 1)))

(defun logos--indicate-buffer-boundaries ()
  "Set `logos-hide-buffer-boundaries'."
  (when logos-hide-buffer-boundaries
    (logos-set-buffer-local-value 'indicate-buffer-boundaries nil)))

(defun logos--hide-cursor ()
  "Set `logos-hide-cursor'."
  (when logos-hide-cursor
    (logos-set-buffer-local-value 'cursor-type nil)))

;; FIXME 2022-03-13: The mode line is not redrawn properly.  Not even
;; with `force-mode-line-update', unless something happens like
;; switching to the other window.  Using `redisplay' does not fix the
;; issue.  I can reproduce the problem on both Emacs 29 and 27.
;;
;; When using `logos-olivetti' the problem no longer occurs, presumably
;; because Olivetti triggers some kind of redraw.  Which one?
;;
;; UPDATE 2022-05-08: If I use `redraw-display', the mode line is
;; restored even without `logos-olivetti'.  This, however, feels like
;; the wrong thing to do because it affects all visible frames.
(defun logos--hide-mode-line ()
  "Set `logos-hide-mode-line'."
  (when logos-hide-mode-line
    (logos-set-buffer-local-value 'mode-line-format nil)))

(defun logos--buffer-read-only ()
  "Set `logos-buffer-read-only'."
  (when logos-buffer-read-only
    (logos-set-buffer-local-value 'buffer-read-only t)))

(defun logos--olivetti ()
  "Set `logos-olivetti'."
  (when (and logos-olivetti (require 'olivetti nil t))
    (logos-set-mode-arg 'olivetti-mode 1)))

(defvar-local logos--fringe-remap-cookie nil
  "Cookie of remapped `fringe' face.")

(declare-function face-remap-add-relative "face-remap" (face &rest specs))
(declare-function face-remap-remove-relative "face-remap" (cookie))

(defun logos--hide-fringe ()
  "Set buffer-local `fringe' to the same background as `default'."
  (when logos-hide-fringe
    (setq logos--fringe-remap-cookie
          (face-remap-add-relative 'fringe :background (face-background 'default)))))

(defun logos--remove-fringe-remap ()
  "Remove effect of `logos--hide-fringe'."
  (when logos--fringe-remap-cookie
    (face-remap-remove-relative logos--fringe-remap-cookie)))

(defun logos--update-fringe (buffer)
  "Update fringe in current BUFFER."
  (with-current-buffer buffer
    (when logos-focus-mode
      (logos--remove-fringe-remap)
      (logos--hide-fringe))))

(defun logos-update-fringe-in-buffers ()
  "Update the `fringe' face across all relevant buffers.
This is only relevant if the user option `logos-hide-fringe' is
non-nil and the `logos-focus-mode' is enabled.

Bind this function to a hook that runs at the post theme load
phase.  For example: `modus-themes-after-load-theme-hook' from
the `modus-themes' (`modus-operandi' and `modus-vivendi' themes
are built into Emacs).

The Logos manual explains how to implement such a hook for any
theme."
  (mapc #'logos--update-fringe (buffer-list)))

(provide 'logos)
;;; logos.el ends here
