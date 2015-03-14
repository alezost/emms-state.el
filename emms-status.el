;;; emms-status.el --- Display track description and playing time in the mode line

;; Copyright © 2015 Alex Kost

;; Author: Alex Kost <alezost@gmail.com>
;; Created: 22 Jan 2015
;; Version: 0.1
;; Package-Requires: ((emms "0"))
;; URL: https://github.com/alezost/emms-status.el
;; Keywords: emms

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a minor mode (`emms-status-mode') for
;; displaying description and playing time of the current track (played
;; by EMMS) in the mode line.  A typical mode line string would look
;; like this (it may be configured with `emms-status-mode-line-string'
;; variable):
;;
;;   ⏵ 1:19(5:14) Chopin - Waltz in a-moll, Op.34 No.2

;; To install the package manually, add the following to your init file:
;;
;;   (add-to-list 'load-path "/path/to/emms-status-dir")
;;   (autoload 'emms-status-mode "emms-status" nil t)

;; This package is intended to be used instead of `emms-mode-line' and
;; `emms-playing-time' modes and it is strongly recommended to disable
;; these modes before enabling `emms-status-mode' (keep in mind that
;; these modes are enabled automatically if you use `emms-all' or
;; `emms-devel' setup function).

;;; Code:

(require 'emms-mode-line)
(require 'emms-playing-time)

(defgroup emms-status nil
  "Display track description and playing time in the mode line."
  :group 'emms)

(defface emms-status-title
  '((t nil))
  "Face used for the title of the current track."
  :group 'emms-status)

(defface emms-status-total-playing-time
  '((t :inherit font-lock-constant-face))
  "Face used for the total playing time."
  :group 'emms-status)

(defface emms-status-current-playing-time
  '((t :inherit font-lock-variable-name-face))
  "Face used for the current playing time."
  :group 'emms-status)

(defcustom emms-status-play "⏵"
  "String used to denote the 'play' state."
  :type 'string
  :group 'emms-status)

(defcustom emms-status-pause "⏸"
  "String used to denote the 'pause' state."
  :type 'string
  :group 'emms-status)

(defcustom emms-status-stop "⏹"
  "String used to denote the 'stop' state."
  :type 'string
  :group 'emms-status)

(defvar emms-status-mode-line-string
  '(" " emms-status-state " "
    (emms-status-current-playing-time
     (:propertize emms-status-current-playing-time
                  face emms-status-current-playing-time))
    (emms-status-total-playing-time
     ("("
      (:propertize emms-status-total-playing-time
                   face emms-status-total-playing-time)
      ")"))
    emms-mode-line-string)
  "Mode line string with the EMMS info.")
(put 'emms-status-mode-line-string 'risky-local-variable t)

(defvar emms-status-state nil
  "Mode line construct for the state of the current EMMS process.")

(defvar emms-status-current-playing-time nil
  "Mode line construct for the current playing time of the track.")

(defvar emms-status-total-playing-time nil
  "Mode line construct for the total playing time of the track.")

(defun emms-status-format-time (time)
  "Convert TIME into a human readable string.
TIME is a number of seconds."
  (let* ((minutes (/ time 60))
         (seconds (% time 60))
         (hours   (/ minutes 60))
         (minutes (% minutes 60)))
    (if (zerop hours)
        (format "%d:%02d" minutes seconds)
      (format "%d:%02d:%02d" hours minutes seconds))))

(defun emms-status-state ()
  "Return string displaying the state of the current EMMS process."
  (if emms-player-playing-p
      (if emms-player-paused-p
          emms-status-pause
        emms-status-play)
    emms-status-stop))

(defun emms-status-set-state ()
  "Update the value of `emms-status-state' variable."
  (setq emms-status-state (emms-status-state)))

(defun emms-status-set-total-playing-time (&optional _)
  "Update the value of `emms-status-total-playing-time' variable.
Optional argument is used to be compatible with
`emms-track-updated-functions'."
  (let ((time (emms-track-get (emms-playlist-current-selected-track)
                              'info-playing-time)))
    (setq emms-status-total-playing-time
          (and time (emms-status-format-time time)))))

(defun emms-status-set-current-playing-time ()
  "Update the value of `emms-status-current-playing-time' variable."
  (setq emms-status-current-playing-time
        (unless (zerop emms-playing-time)
          (emms-status-format-time emms-playing-time))))


;;; Playing time functions for hooks

(defun emms-status-timer-start ()
  "Start timer for the current playing time."
  (unless emms-playing-time-display-timer
    (setq emms-playing-time-display-timer
          (run-at-time t 1 'emms-status-playing-time-step))))

(defun emms-status-timer-stop ()
  "Stop timer for the current playing time."
  (emms-cancel-timer emms-playing-time-display-timer)
  (setq emms-playing-time-display-timer nil)
  (emms-status-playing-time-update))

(defun emms-status-playing-time-step ()
  "Shift the current playing time by one second."
  (setq emms-playing-time (round (1+ emms-playing-time)))
  (emms-status-playing-time-update))

(defun emms-status-playing-time-update ()
  "Update the current playing time in the mode line."
  (emms-status-set-current-playing-time)
  (force-mode-line-update))

(defun emms-status-playing-time-start ()
  "Start displaying the current playing time."
  (setq emms-playing-time 0)
  (emms-status-timer-start))

(defun emms-status-playing-time-stop ()
  "Stop displaying the current playing time."
  (setq emms-playing-time 0)
  (emms-status-timer-stop))

(defun emms-status-playing-time-pause ()
  "Pause displaying the current playing time."
  (if emms-player-paused-p
      (emms-status-timer-stop)
    (emms-status-timer-start)))

(defalias 'emms-status-playing-time-seek 'emms-playing-time-seek)
(defalias 'emms-status-playing-time-set 'emms-playing-time-set)


;;; Commands

;;;###autoload
(define-minor-mode emms-status-mode
  "Minor mode for displaying some EMMS info in the mode line.

This mode is intended to be a substitution for `emms-mode-line'
and `emms-playing-time'."
  :global t
  (or global-mode-string (setq global-mode-string '("")))
  (let (hook-action activep)
    (if emms-status-mode
        ;; Turn on.
        (progn
          (setq hook-action 'add-hook
                activep t)
          (when emms-player-playing-p (emms-mode-line-alter))
          (emms-status-toggle-mode-line 1))
      ;; Turn off.
      (setq hook-action 'remove-hook
            activep nil)
      (emms-status-playing-time-stop)
      (emms-mode-line-restore-titlebar)
      (emms-status-toggle-mode-line -1))

    (force-mode-line-update)
    (setq emms-mode-line-active-p activep
          emms-playing-time-p activep
          emms-playing-time-display-p activep)

    (funcall hook-action 'emms-track-updated-functions
             'emms-mode-line-alter)
    (funcall hook-action 'emms-player-started-hook
             'emms-mode-line-alter)

    (funcall hook-action 'emms-track-updated-functions
             'emms-status-set-total-playing-time)
    (funcall hook-action 'emms-player-started-hook
             'emms-status-set-total-playing-time)

    (funcall hook-action 'emms-player-started-hook
             'emms-status-set-state)
    (funcall hook-action 'emms-player-stopped-hook
             'emms-status-set-state)
    (funcall hook-action 'emms-player-finished-hook
             'emms-status-set-state)
    (funcall hook-action 'emms-player-paused-hook
             'emms-status-set-state)

    (funcall hook-action 'emms-player-started-hook
             'emms-status-playing-time-start)
    (funcall hook-action 'emms-player-stopped-hook
             'emms-status-playing-time-stop)
    (funcall hook-action 'emms-player-finished-hook
             'emms-status-playing-time-stop)
    (funcall hook-action 'emms-player-paused-hook
             'emms-status-playing-time-pause)
    (funcall hook-action 'emms-player-seeked-functions
             'emms-status-playing-time-seek)
    (funcall hook-action 'emms-player-time-set-functions
             'emms-status-playing-time-set)))

(defun emms-status-toggle-mode-line (&optional arg)
  "Toggle displaying EMMS status info in the mode line.

With prefix argument ARG, enable status info if ARG is positive,
disable otherwise.

Unlike `emms-status-mode', this function will just remove
`emms-status-mode-line-string' from `global-mode-string'.  The
playing timer will still go on."
  (interactive "P")
  (if (or (and (null arg)
               (not (memq 'emms-status-mode-line-string
                          global-mode-string)))
          (and arg
               (> (prefix-numeric-value arg) 0)))
      (add-to-list 'global-mode-string
                   'emms-status-mode-line-string
                   'append)
    (setq global-mode-string
          (remove 'emms-status-mode-line-string
                  global-mode-string)))
  (force-mode-line-update))

(provide 'emms-status)

;;; emms-status.el ends here
