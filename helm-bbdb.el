;;; helm-bbdb.el --- Helm interface for bbdb -*- lexical-binding: t -*-

;; Copyright (C) 2012-2026 Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; Version: 1.0
;; Package-Requires: ((emacs "26.1") (helm "1.5") (bbdb "3.1.2"))
;; URL: https://github.com/emacs-helm/helm-bbdb

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

;; This is a Helm interface for BBDB, the Insidious Big Brother
;; Database for GNU Emacs.

;;; Code:

(require 'cl-lib)
(require 'helm)
(require 'helm-utils)
(require 'helm-mode)

(defvar bbdb-records)
(defvar bbdb-buffer-name)
(defvar bbdb-phone-label-list)
(defvar bbdb-address-label-list)
(defvar bbdb-default-xfield)

(declare-function bbdb-record-mail "ext:bbdb-com" (record) t)
(declare-function bbdb-records "ext:bbdb" ())
(declare-function bbdb-create-internal "ext:bbdb-com")
(declare-function bbdb-read-organization "ext:bbdb-com")
(declare-function bbdb-read-xfield "ext:bbdb-com")
(declare-function bbdb-read-string "ext:bbdb")
(declare-function bbdb-record-edit-address "ext:bbdb-com")
(declare-function bbdb-string-trim "ext:bbdb")
(declare-function bbdb-split "ext:bbdb" (separator string))
(declare-function bbdb-display-records "ext:bbdb"
                  (records &optional layout append select horiz-p))
(declare-function bbdb-display-record "ext:bbdb" (record layout number))
(declare-function bbdb-delete-records "ext:bbdb-com" (records &optional noprompt))
(declare-function bbdb-record-name "ext:bbdb")

(defconst helm-bbdb--end-street-lines-value
  'helm-bbdb--end-street-lines)

(defconst helm-bbdb--blank-address-field-value
  'helm-bbdb--blank-address-field)

(defconst helm-bbdb--end-street-lines-candidate
  (cons "[End street lines]" helm-bbdb--end-street-lines-value))

(defconst helm-bbdb--blank-address-field-candidate
  (cons "[Leave blank]" helm-bbdb--blank-address-field-value))

(defvar helm-bbdb--editing-address nil)

;; Match the standard prompt suffixes used by BBDB 3.x. IDENT may
;; prepend arbitrary text, so these expressions are deliberately
;; anchored only at the end.
(defun helm-bbdb--street-prompt-p (prompt)
  "Return non-nil when PROMPT reads a BBDB street line."
  (and (stringp prompt)
       (string-match-p "Street, line [0-9]+: \\'" prompt)))

(defun helm-bbdb--address-field-prompt-p (prompt)
  "Return non-nil when PROMPT reads a BBDB address subfield."
  (and (stringp prompt)
       (string-match-p "\\(?:City\\|State\\|Postcode\\|Country\\): \\'"
                       prompt)))

(defun helm-bbdb--record-edit-address (orig-fun &rest args)
  "Call ORIG-FUN with BBDB address completion helpers enabled.
ARGS are the arguments passed to `bbdb-record-edit-address'."
  (let ((helm-bbdb--editing-address t))
    (apply orig-fun args)))

(defun helm-bbdb--read-address-string
    (prompt collection empty-candidate empty-value
            &optional init require-match)
  "Read a BBDB address string with Helm.
PROMPT, COLLECTION, INIT, and REQUIRE-MATCH are passed to
`helm-comp-read'. EMPTY-CANDIDATE is added before COLLECTION. When Helm
returns EMPTY-VALUE, return an empty string."
  (let ((value (helm-comp-read prompt
                               (cons empty-candidate collection)
                               :initial-input init
                               :must-match require-match)))
    (cond
     ((eq value empty-value) "")
     ((stringp value) (bbdb-string-trim value))
     (t (error "Unexpected BBDB address value: %S" value)))))

(defun helm-bbdb--bbdb-read-string
    (orig-fun prompt &optional init collection require-match)
  "Read BBDB address fields with explicit empty candidates.
Call ORIG-FUN outside `bbdb-record-edit-address' and for non-address
prompts.  INIT, COLLECTION, and REQUIRE-MATCH are the arguments passed to
`bbdb-read-string'."
  (cond
   ((and helm-bbdb--editing-address
         collection
         (helm-bbdb--street-prompt-p prompt))
    (helm-bbdb--read-address-string
     prompt collection
     helm-bbdb--end-street-lines-candidate
     helm-bbdb--end-street-lines-value
     init require-match))
   ((and helm-bbdb--editing-address
         collection
         (helm-bbdb--address-field-prompt-p prompt))
    (helm-bbdb--read-address-string
     prompt collection
     helm-bbdb--blank-address-field-candidate
     helm-bbdb--blank-address-field-value
     init require-match))
   (t
    (funcall orig-fun prompt init collection require-match))))

(unless (advice-member-p #'helm-bbdb--record-edit-address
                         'bbdb-record-edit-address)
  (advice-add 'bbdb-record-edit-address
              :around #'helm-bbdb--record-edit-address))
(unless (advice-member-p #'helm-bbdb--bbdb-read-string 'bbdb-read-string)
  (advice-add 'bbdb-read-string :around #'helm-bbdb--bbdb-read-string))

(defun helm-bbdb-unload-function ()
  "Remove advice installed by `helm-bbdb'."
  (advice-remove 'bbdb-record-edit-address
                 #'helm-bbdb--record-edit-address)
  (advice-remove 'bbdb-read-string #'helm-bbdb--bbdb-read-string)
  nil)

(defgroup helm-bbdb nil
  "Commands and functions for bbdb."
  :group 'helm)

(defcustom helm-bbdb-actions
  (helm-make-actions
   "View contact" #'helm-bbdb-view-person-action
   "Compose email" #'helm-bbdb-compose-mail
   "Delete contact" #'helm-bbdb-delete-contact)
  "Actions available for BBDB candidates."
  :type '(alist :key-type string :value-type function)
  :group 'helm-bbdb)

(defcustom helm-bbdb-display-style 'one-line
  "How BBDB candidates are displayed and searched.
With `name', candidates contain only the contact name. With `one-line',
candidates use BBDB's `one-line' layout; fields present in that layout
are searchable by Helm."
  :type '(choice
          (const :tag "Name only" name)
          (const :tag "BBDB one-line layout" one-line))
  :group 'helm-bbdb)

(defun helm-bbdb--record-display-name (record)
  "Return a display name for RECORD."
  (let ((name (bbdb-record-name record)))
    (if (or (not name) (string= name ""))
        "???"
      name)))

(defun helm-bbdb--candidate (display record)
  "Return a Helm candidate with DISPLAY and BBDB RECORD."
  (cons display record))

(defun helm-bbdb--one-line-display (record)
  "Return RECORD formatted using BBDB's one-line layout."
  (erase-buffer)
  (bbdb-display-record record 'one-line 0)
  (let ((display
         (replace-regexp-in-string
          "[ \t\n]*\\'" ""
          (buffer-substring-no-properties
           (point-min) (point-max)))))
    (if (string= display "")
        (helm-bbdb--record-display-name record)
      display)))

(defun helm-bbdb-candidates ()
  "Return BBDB records using `helm-bbdb-display-style'."
  (pcase helm-bbdb-display-style
    ('one-line
     (with-temp-buffer
       (cl-loop for record in (bbdb-records)
                collect
                (helm-bbdb--candidate
                 (helm-bbdb--one-line-display record)
                 record))))
    ('name
     (cl-loop for record in (bbdb-records)
              collect (helm-bbdb--candidate
                       (helm-bbdb--record-display-name record)
                       record)))
    (_
     (error "Invalid `helm-bbdb-display-style': %S"
            helm-bbdb-display-style))))

(defun helm-bbdb-read-phone ()
  "Return a list of BBDB phone vectors.
See docstring of `bbdb-create-internal' for phone vector details."
  (cl-loop with loc-list = (cons "[Exit when no more]" bbdb-phone-label-list)
           with loc ; Defer count
           do (setq loc (helm-comp-read (format "Phone location[%s]: " count)
                                        loc-list
                                        :must-match 'confirm
                                        :default ""))
           while (not (string= loc "[Exit when no more]"))
           for count from 1
           for phone-number = (helm-read-string (format "Phone number (%s): " loc))
           collect (vector loc phone-number) into phone-list
           do (setq loc-list (remove loc loc-list))
           finally return phone-list))

(defun helm-bbdb-read-address ()
  "Return a list of vector address objects.
See docstring of `bbdb-create-internal' for address vector details."
  (cl-loop with loc-list = (cons "[Exit when no more]" bbdb-address-label-list)
           with loc ; Defer count
           do (setq loc (helm-comp-read
                         (format "Address description[%s]: "
                                 (int-to-string count))
                         loc-list
                         :must-match 'confirm
                         :default ""))
           while (not (string= loc "[Exit when no more]"))
           for count from 1
           ;; Create vector
           for lines = (helm-read-repeat-string "Street, line" t)
           for city = (helm-read-string "City: ")
           for state = (helm-read-string "State: ")
           for zip = (helm-read-string "ZipCode: ")
           for country = (helm-read-string "Country: ")
           collect (vector loc lines city state zip country) into address-list
           do (setq loc-list (remove loc loc-list))
           finally return address-list))

(defun helm-bbdb-create-contact (actions candidate)
  "Action transformer for `helm-source-bbdb'.
Returns only an entry to add the current `helm-pattern' as new contact.
All other actions are removed."
  (require 'bbdb-com)
  (if (and (stringp candidate)
           (string= candidate "*Add new contact*"))
      (helm-make-actions
       "Add to contacts"
       (lambda (_actions)
         (bbdb-create-internal
          :name (read-from-minibuffer "Name: " helm-pattern)
          :organization (bbdb-read-organization)
          :mail (helm-read-repeat-string "Email " t)
          :phone (helm-bbdb-read-phone)
          :address (helm-bbdb-read-address)
          :xfields (let ((xfield (bbdb-read-xfield bbdb-default-xfield)))
		             (unless (string= xfield "")
		               (list (cons bbdb-default-xfield xfield)))))))
    actions))

(defvar helm-source-bbdb
  (helm-build-sync-source "BBDB"
    :init (lambda ()
            (require 'bbdb))
    :candidates 'helm-bbdb-candidates
    :action 'helm-bbdb-actions
    :persistent-action 'helm-bbdb-persistent-action
    :persistent-help "View data"
    :filtered-candidate-transformer (lambda (candidates _source)
                                      (if candidates
                                          candidates
                                        (list "*Add new contact*")))
    :action-transformer (lambda (actions candidate)
                          (helm-bbdb-create-contact actions candidate)))
  "Source for BBDB.")

(defun helm-bbdb-view-person-action (_candidate)
  "Display the selected or marked BBDB records."
  (bbdb-display-records (helm-marked-candidates) nil nil t))

(defun helm-bbdb-persistent-action (record)
  "Display RECORD using Helm's persistent action."
  (let ((bbdb-silent t))
    (bbdb-display-records (list record))))

(defun helm-bbdb--record-mails (record)
  "Return normalized mail addresses for RECORD."
  (cl-loop for mail in (bbdb-record-mail record)
           append (bbdb-split 'mail mail)))

(defun helm-bbdb-collect-mail-addresses ()
  "Return a list of the mail addresses of candidates.
If record has more than one address, prompt for an address."
  (cl-loop for record in (helm-marked-candidates)
	       for mails = (helm-bbdb--record-mails record)
	       when mails collect
	       (if (cdr mails)
	           (helm-comp-read "Choose mail: "
			                   (mapcar (lambda (mail)
					                     (bbdb-dwim-mail record mail))
				                       mails)
			                   :allow-nest t
			                   :initial-input helm-pattern)
	         (bbdb-dwim-mail record (car mails)))))

(defun helm-bbdb-collect-all-mail-addresses ()
  "Return a list of strings to use as the mail address of record.
This may include multiple addresses of the same record. The name in the
mail address is formatted obeying `bbdb-mail-name-format' and
`bbdb-mail-name'."
  (let (mails)
    (dolist (record (bbdb-records))
      (dolist (mail (helm-bbdb--record-mails record))
        (push (bbdb-dwim-mail record mail) mails)))
    (nreverse mails)))

(defun helm-bbdb-compose-mail (_candidate)
  "Compose a new mail to one or multiple CANDIDATEs."
  (let* ((address-list (helm-bbdb-collect-mail-addresses))
         (address-str  (mapconcat 'identity address-list ",\n    ")))
    (compose-mail address-str nil nil nil 'switch-to-buffer)))

(defun helm-bbdb-delete-contact (_candidate)
  "Delete CANDIDATE from the bbdb buffer and database.
Prompt user to confirm deletion."
  (let* ((records (helm-marked-candidates))
         (count (length records))
         (names (mapcar #'helm-bbdb--record-display-name records))
         (noun (if (= count 1) "contact" "contacts")))
    (unless records
      (user-error "No BBDB contacts selected"))
    (with-helm-display-marked-candidates
      "*BBDB contacts*" names
      (when (y-or-n-p (format "Delete %s?" noun))
        (bbdb-delete-records records t)
        (message "%d %s deleted:\n- %s"
                 count noun
                 (mapconcat #'identity names "\n- "))))))

(defun helm-bbdb-insert-mail (_candidate &optional comma)
  "Insert CANDIDATE's email address.
If optional argument COMMA is non-nil, insert comma separator as well,
which is needed when executing persistent action."
  (let* ((address-list (helm-marked-candidates))
         (address-str  (mapconcat 'identity address-list ",\n    ")))
    (end-of-line)
    (while (not (looking-back ": \\|, \\| [ \t]" (point-at-bol)))
      (delete-char -1))
    (insert (concat address-str (when comma ", ")))
    (end-of-line)))

(defun helm-bbdb-expand-name ()
  "Expand name under point when there is one.
Otherwise, open a helm buffer displaying a list of addresses. If
`bbdb-complete-mail-allow-cycling' is non-nil and point is at the end of
the address line, cycle mail addresses of record. To use this feature,
make sure `helm-bbdb-expand-name' is added to the
`message-completion-alist' variable."
  (if (and (looking-back "\\(<.+\\)\\(@\\)\\(.+>$\\)" nil)
           bbdb-complete-mail-allow-cycling)
      (bbdb-complete-mail)
    (let (mails
          (abbrev (thing-at-point 'symbol t)))
      (with-temp-buffer
        (mapc (lambda (mail)
                (insert (concat mail "\n")))
              (helm-bbdb-collect-all-mail-addresses))
        (goto-char (point-min))
        (while (re-search-forward (concat "\\(^.+\\)" "\\(" abbrev "\\)" "\\(.+$\\)") nil t)
          (push (concat (match-string 1) (match-string 2) (match-string 3)) mails)))
      ;; If there's one address, insert it automatically
      (if (= (length mails) 1)
          (progn (end-of-line)
                 (while (not (looking-back ": \\|, \\| [ \t]" (point-at-bol)))
                   (delete-char -1))
                 (insert (car mails))
                 (end-of-line))
        ;; If there's more than one, start helm
        (helm :sources
              (helm-build-sync-source "BBDB"
                :candidates 'helm-bbdb-collect-all-mail-addresses
                :persistent-action (lambda (candidate)
                                     (helm-bbdb-insert-mail candidate t))
                :action 'helm-bbdb-insert-mail)
              :input (thing-at-point 'symbol t))))))

;;;###autoload
(defun helm-bbdb ()
  "Preconfigured `helm' for BBDB.

Needs BBDB.

URL `http://bbdb.sourceforge.net/'"
  (interactive)
  (helm-other-buffer 'helm-source-bbdb "*helm bbdb*"))

(provide 'helm-bbdb)

;; Local Variables:
;; byte-compile-warnings: (not obsolete)
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-bbdb.el ends here
