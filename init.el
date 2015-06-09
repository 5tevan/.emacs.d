;; Turn off interface
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'menu-bar-mode) (menu-bar-mode -1))

(setq inhibit-startup-message t)

(setq is-windows (eq system-type 'windows-nt))

;; Keep emacs Custom-settings in separate file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;; Add melpa as a package repo
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "http://melpa.org/packages/") t)
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/")))
(package-initialize)

(defmacro !cdr (list)
  "Destructive: Set LIST to the cdr of LIST."
  `(setq ,list (cdr ,list)))

(defmacro --each (list &rest body)
  "Anaphoric form of `-each'."
  (declare (debug (form body))
           (indent 1))
  (let ((l (make-symbol "list")))
    `(let ((,l ,list)
           (it-index 0))
       (while ,l
         (let ((it (car ,l)))
           ,@body)
         (setq it-index (1+ it-index))
         (!cdr ,l)))))

(defun packages-install (packages)
  (--each packages
    (when (not (package-installed-p it))
      (package-install it)))
  (delete-other-windows))

;; Install extensions if they're missing
(defun init--install-packages ()
  (packages-install
   '(
     async
     auto-complete
     autopair
     emmet-mode
     expand-region
     helm
     ido-vertical-mode
     magit
     markdown-mode
     monokai-theme
     multiple-cursors
     mustache-mode
     nginx-mode
     paredit
     php-mode
     restclient
     web-mode
     )))

(condition-case nil
    (init--install-packages)
  (error
   (package-refresh-contents)
   (init--install-packages)))

(show-paren-mode 1)

;; Auto Complete
(require 'auto-complete-config)
(ac-config-default)

;; Theme
(load-theme 'monokai t)

;; Font
(if is-windows
    (set-default-font "Consolas-12")
  (set-default-font "Droid Sans Mono-11"))

(defun string-starts-with (haystack needle)
  (string=
   (substring haystack 0 (length needle))
   needle))

(defun is-starred-buffer (name)
  (or
   (string-starts-with name " *")
   (string-starts-with name "*")))

(defun unstarred-buffers ()
  (remove-if
   #'is-starred-buffer
   (mapcar (function buffer-name) (buffer-list))))

(defun cycle-buffers (buffer-func)
  "skip starred buffers if there are other buffers"
  (if (unstarred-buffers)
      (progn
	(funcall buffer-func)
	(while (is-starred-buffer (buffer-name))
	  (funcall buffer-func)))
    (funcall buffer-func)))

(defun next-buffer-skip-starred ()
  "next-buffer that skips certain buffers"
  (interactive)
  (cycle-buffers #'next-buffer))

(defun previous-buffer-skip-starred ()
  "previous-buffer that skips certain buffers"
  (interactive)
  (cycle-buffers #'previous-buffer))

(defun next-buffer-or-window ()
  (interactive)
  (if (eq 1 (length (window-list)))
      (next-buffer-skip-starred)
    (other-window 1)))

(defun previous-buffer-or-window ()
  (interactive)
  (if (eq 1 (length (window-list)))
      (previous-buffer-skip-starred)
    (other-window -1)))

;; Movement
(global-set-key [C-tab] 'next-buffer-or-window)
(global-set-key [C-S-tab] 'previous-buffer-or-window)
(global-set-key [C-S-iso-lefttab] 'previous-buffer-or-window)

(global-set-key (kbd "C-x C-m") 'helm-M-x)
(global-set-key (kbd "C-c C-m") 'helm-M-x)

;; Always display line and column numbers
(setq line-number-mode t)
(setq column-number-mode t)

;; Emmet
(require 'emmet-mode)
(add-hook 'sgml-mode-hook 'emmet-mode)

;; Ido
(setq ido-enable-flex-matching t)
(setq ido-everywhere t)
(setq ido-create-new-buffer 'always)
(ido-mode 1)

(require 'ido-vertical-mode)
(ido-vertical-mode)

;; Lisp specific defuns
(defun eval-and-replace ()
  "Replace the preceding sexp with its value."
  (interactive)
  (backward-kill-sexp)
  (condition-case nil
      (prin1 (eval (read (current-kill 0)))
             (current-buffer))
    (error (message "Invalid expression")
           (insert (current-kill 0)))))

(global-set-key (kbd "C-c C-e") 'eval-and-replace)

;; Paredit
(add-hook 'emacs-lisp-mode-hook #'paredit-mode)

;; Autopair
(require 'autopair)
(add-hook 'text-mode-hook #'(lambda () (autopair-mode 1)))
(add-hook 'html-mode-hook #'(lambda () (autopair-mode 1)))
(add-hook 'lisp-mode-hook #'(lambda () (autopair-mode 1)))

;; Multiple Cursors
(require 'multiple-cursors)
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

;; Expand Region
(require 'expand-region)
(global-set-key (kbd "C-'") 'er/expand-region)
(global-set-key (kbd "C-\"") 'er/contract-region)
(delete-selection-mode 1)

;; Helm
(require 'helm-config)
(helm-mode 1)
(global-set-key (kbd "M-x") 'helm-M-x)
(setq helm-M-x-fuzzy-match t)
(helm-autoresize-mode 1)

;; Toggle Comment
(defun toggle-comment-on-line ()
  "Comment or uncomment current line"
  (interactive)
  (comment-or-uncomment-region (line-beginning-position) (line-end-position)))

(global-set-key (kbd "C-c C-c") 'toggle-comment-on-line)

;; Buffer cleanup defuns

(defun untabify-buffer ()
  (interactive)
  (untabify (point-min) (point-max)))

(defun indent-buffer ()
  (interactive)
  (indent-region (point-min) (point-max)))

(defun cleanup-buffer ()
  "Perform a bunch of operations on the whitespace content of a buffer.
Including indent-buffer, which should not be called automatically on save."
  (interactive)
  (untabify-buffer)
  (delete-trailing-whitespace)
  (indent-buffer))

(defadvice sgml-delete-tag (after reindent-buffer activate)
  (cleanup-buffer))
