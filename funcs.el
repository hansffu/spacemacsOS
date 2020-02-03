;; -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Can be used to bind a key to jumping to an application, or alternatively starting it.  E.g.:
;;
;; (exwm/bind-switch-to-or-run-command "s-f" "Firefox" "firefox")
;;
;; The window class can be found out with exwm's builtin info functions, but for most applications it should just match the buffer name.
(defun exwm/bind-switch-to-or-run-command (key window-class command)
  (exwm-input-set-key (kbd key)
                      `(lambda ()
                         (interactive)
                         (exwm/switch-to-buffer-or-run ,window-class ,command))))

;; (defun exwm//switch-to-line-mode ()
;;   "Used as a hook to switch to line mode when transient mode starts."
;;   (when (eq exwm--input-mode 'char-mode)
;;     ;; (setq exwm--switch-to-char-after-transient (current-buffer))
;;     (call-interactively 'exwm-input-grab-keyboard)))

(defun exwm//persp-mode-inhibit-p (frame)
  (frame-parameter frame 'unsplittable))

(defun exwm/bind-command (key command &rest bindings)
  (while key
    (exwm-input-set-key (kbd key)
                        `(lambda ()
                           (interactive)
                           (start-process-shell-command ,command nil ,command)))
    (setq key     (pop bindings)
          command (pop bindings))))

;; Simulate insert state by using line mode without passthrough
(defun exwm/enter-insert-state ()
  (interactive)
  (setq exwm-input-line-mode-passthrough nil)
  (evil-insert-state))

;; Simulate normal state by using line mode with passthrough, i.e. forward all commands to emacs
(defun exwm/enter-normal-state ()
  (interactive)
  (setq exwm-input-line-mode-passthrough t)
  (evil-normal-state))

(defun exwm/escape ()
  "Switch to normal state, and cancel possible fullscreen layout."
  (interactive)
  (exwm/enter-normal-state)
  (exwm-layout-unset-fullscreen))

(defun exwm/switch-to-buffer-or-run (window-class command)
  "Switch to first buffer with window-class, and if not present, run command."
  (let ((buffer
         (cl-find window-class (buffer-list) :key (lambda(b) (cdr (assoc 'exwm-class-name (buffer-local-variables b)))) :test 'string-equal)))
    (if buffer
        (exwm-workspace-switch-to-buffer buffer)
      (start-process-shell-command command nil command))))

;; All buffers created in EXWM mode are named "*EXWM*". You may want to change
;; it in `exwm-update-class-hook' and `exwm-update-title-hook', which are run
;; when a new window class name or title is available. Here's some advice on
;; this subject:
;; + Always use `exwm-workspace-rename-buffer` to avoid naming conflict.
;; + Only renaming buffer in one hook and avoid it in the other. There's no
;;   guarantee on the order in which they are run.
;; + For applications with multiple windows (e.g. GIMP), the class names of all
;;   windows are probably the same. Using window titles for them makes more
;;   sense.
;; + Some application change its title frequently (e.g. browser, terminal).
;;   Its class name may be more suitable for such case.
;; In the following example, we use class names for all windows expect for
;; Java applications and GIMP.
(defun exwm/rename-buffer ()
  (let* ((part1 exwm-class-name)
         (part2 (when (not (string-equal exwm-class-name exwm-title))
                  (concat "/" exwm-title)))
         (name (concat exwm-buffer-name-prefix part1 (or part2 "")))
         (maxlen 40))
    (exwm-workspace-rename-buffer (if (> (length name) maxlen)
                                      (concat (cl-subseq name 0 (- maxlen 3)) "...")
                                    name))))

;; unused, untested
(defun exwm/workspace-next ()
  "Switch to next exwm-workspace (to the right)."
  (interactive)
  (let ((max (exwm-workspace--count)))
    (exwm-workspace-switch (mod (1+ exwm-workspace-current-index) max))))

(defun exwm/workspace-prev ()
  "Switch to next exwm-workspace (to the left)."
  (interactive)
  (let ((max (exwm-workspace--count)))
    (exwm-workspace-switch (mod (1- exwm-workspace-current-index) max))))

(defun exwm/layout-toggle-fullscreen ()
  "Togggles full screen for Emacs and X windows"
  (interactive)
  (if exwm--id
      (if (exwm-layout--fullscreen-p)
          (exwm-reset)
        (exwm-layout-set-fullscreen))
    (spacemacs/toggle-maximize-buffer)))

(defun exwm/run-program-in-home (command)
  (let ((default-directory user-home-directory))
    (start-process-shell-command command nil command)))

(defun exwm/app-launcher (command)
  "Launches an application in your PATH.
Can show completions at point for COMMAND using helm or ivy"
  (interactive (list (read-shell-command exwm-app-launcher--prompt)))
  (exwm/run-program-in-home command))

(defun exwm/launch-split-below (command)
  (interactive (list (read-shell-command exwm-app-launcher--prompt)))
  (split-window-below-and-focus)
  (exwm/run-program-in-home command))

(defun exwm/launch-split-right (command)
  (interactive (list (read-shell-command exwm-app-launcher--prompt)))
  (split-window-right-and-focus)
  (exwm/run-program-in-home command))

(defun exwm/jump-to-last-exwm ()
  (interactive)
  (exwm-workspace-switch exwm-toggle-workspace))

(defun exwm/exwm-buffers-info ()
  (interactive)
  "Helper, return information about open exwm windows"
  (cl-loop for buffer in (buffer-list)
        for name = (buffer-name buffer)
        for ecname = (buffer-local-value 'exwm-class-name buffer)
        when ecname
        do (message "Buffer name: '%s', exwm class name: '%s'" name ecname)))

(defun exwm//convert-key-to-event (key)
  "Converts something from (kbd ...) format to something suitable for
    exwm-input-prefix-keys"
  (let ((key (kbd key)))
    (if (and (sequencep key)
             (= (length key) 1))
        (etypecase key
          (string (string-to-char key))
          (vector (elt key 0)))
      (error "cannot convert to key event: %s" key))))


(let ((debug-modes-active nil))
  (defun exwm/toggle-debug-mode ()
   "Toggle exwm and xcb debug modes"
   (interactive)
   (setf debug-modes-active (not debug-modes-active))
   (message (if debug-modes-active
                "Enabling xcb and exwm debug modes."
              "Disabling xcb and exqm debug modes."))
   (let ((flag (if debug-modes-active 1 0)))
     (exwm-debug flag)
     (xcb:debug flag))))

(defvar exwm//autostart-process-list nil
  "List of processes run during autostart.")

(defun exwm/autostart-process (name command)
  "Can be used during initialization to run COMMAND as a process
  with NAME and add it to the list of autostarted processes."
  (push (start-process-shell-command name nil command)
        exwm//autostart-process-list))

(defun exwm//autostart-desktop-applications ()
  "Run XDG autostart applications."
  (unless exwm//autostart-process-list
    (let ((config-dir (expand-file-name "autostart/" (xdg-config-home))))
      (when (file-accessible-directory-p config-dir)
        (let ((desktop-files (directory-files config-dir t "[^.].*")))
          (cl-loop for f in desktop-files
                when (file-readable-p f)
                for xdg = (xdg-desktop-read-file f)
                for name = (gethash "Name" xdg)
                for cmd = (gethash "Exec" xdg)
                do (exwm/autostart-process name cmd)
                ))))))

(defun exwm//kill-autostart-processes ()
  (cl-loop for p in exwm//autostart-process-list do
        (if (process-live-p p) (kill-process p)))
  (setq exwm//autostart-process-list nil))

(let ((sm-keyvec (elt (edmacro-parse-keys dotspacemacs-leader-key t) 0))
      (our-keyvec (elt (edmacro-parse-keys "s-SPC" t) 0)))
  (defun exwm//which-key-transform-filter (oldargs)
    (destructuring-bind (key-seq &rest rest) oldargs
      (list* (cl-substitute sm-keyvec our-keyvec key-seq) rest))))

;; D-Bus locking
;; We should be able to talk to loginctl to handle the current session, so we
;; can react to the lock signal.

(defun exwm//install-logind-lock-handler ()
  (let ((session (dbus-call-method :system "org.freedesktop.login1" "/org/freedesktop/login1"
                                   "org.freedesktop.login1.Manager" "GetSessionByPID" (emacs-pid))))
    (dbus-register-signal :system "org.freedesktop.login1" session
                          "org.freedesktop.login1.Session" "Lock"
                          (lambda()
                            (message "Lock signal received")
                            (start-process-shell-command "session-lock" nil exwm-locking-command)))))
