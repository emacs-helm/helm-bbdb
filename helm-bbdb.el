;;; helm-bbdb.el --- Helm interface for bbdb -*- lexical-binding: t -*-

;; Copyright (C) 2012 ~ 2015 Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; Version: 1.7
;; Package-Requires: ((helm "1.5") (bbdb "3.1.2"))
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

(declare-function bbdb "ext:bbdb-com")
(declare-function bbdb-current-record "ext:bbdb-com")
(declare-function bbdb-redisplay-record "ext:bbdb-com")
(declare-function bbdb-record-mail "ext:bbdb-com" (record) t)
(declare-function bbdb-mail-address "ext:bbdb-com")
(declare-function bbdb-records "ext:bbdb-com")
(declare-function bbdb-create-internal "ext:bbdb-com")
(declare-function bbdb-read-organization "ext:bbdb-com")
(declare-function bbdb-read-xfield "ext:bbdb-com")
(declare-function bbdb-display-records "ext:bbdb")
(declare-function bbdb-current-field "ext:bbdb")
(declare-function bbdb-delete-field-or-record "ext:bbdb-com")

(defgroup helm-bbdb nil
  "Commands and function for bbdb."
  :group 'helm)

(defcustom helm-bbdb-actions
  (helm-make-actions
   "View contact's data" 'helm-bbdb-view-person-action
   "Copy contact's email" 'helm-bbdb-copy-mail-address
   "Delete contact" 'helm-bbdb-delete-contact
   "Send an email" 'helm-bbdb-compose-mail)
  "Default actions alist for `helm-source-bbdb'."
  :type '(alist :key-type string :value-type function))

(defun helm-bbdb-candidates ()
  "Return a list of all names in the bbdb database.
The format is \"Firstname Lastname\"."
  (require 'bbdb)
  (mapcar (lambda (bbdb-record)
            (let ((name1 (aref bbdb-record 0))
                  (name2 (aref bbdb-record 1)))
              (cond ((and name1 name2)
                     (concat name1 " " name2))
                    (name1)
                    (name2))))
          (bbdb-records)))

(defun helm-bbdb-read-phone ()
  "Return a list of vector address objects.
See docstring of `bbdb-create-internal' for more info on address entries."
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
See docstring of `bbdb-create-internal' for more info on address entries."
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
  (if (string= candidate "*Add new contact*")
      (helm-make-actions
       "Add to contacts"
       (lambda (_actions)
         (bbdb-create-internal
          (read-from-minibuffer "Name: " helm-pattern)
          nil nil
          (bbdb-read-organization)
          (helm-read-repeat-string "Email " t)
          (helm-bbdb-read-phone)
          (helm-bbdb-read-address)
          (let ((xfield (bbdb-read-xfield bbdb-default-xfield)))
            (unless (string= xfield "")
              (list (cons bbdb-default-xfield xfield)))))))
    actions))

(defun helm-bbdb-get-record (candidate)
  "Return record that match CANDIDATE."
  (cl-letf (((symbol-function 'message) #'ignore)) 
    (bbdb candidate nil)
    (set-buffer bbdb-buffer-name)
    (prog1
        (bbdb-current-record)
      (delete-window))))

(defun helm-bbdb-match-fn (candidate)
  "Additional match function that match email address of CANDIDATE."
  (string-match helm-pattern
                (car
                 (bbdb-record-mail
                  (helm-bbdb-get-record candidate))))))

(defvar helm-source-bbdb
  (helm-build-sync-source "BBDB"
    :candidates 'helm-bbdb-candidates
    :match 'helm-bbdb-match-fn 
    :action 'helm-bbdb-actions
    :filtered-candidate-transformer (lambda (candidates _source)
                                      (if (not candidates)
                                          (list "*Add new contact*")
                                          candidates))
    :action-transformer (lambda (actions candidate)
                          (helm-bbdb-create-contact actions candidate)))
  "Needs BBDB.

URL `http://bbdb.sourceforge.net/'")

(defun helm-bbdb-view-person-action (_candidate)
  "View BBDB data of single CANDIDATE or marked candidates."
  (bbdb-display-records
   (mapcar 'helm-bbdb-get-record (helm-marked-candidates)) nil t))

(defun helm-bbdb-collect-mail-addresses ()
  "Return a list of all mail addresses of records in bbdb buffer."
  (with-current-buffer bbdb-buffer-name
    (cl-loop for i in bbdb-records
             for mails = (bbdb-record-mail (car i))
             when mails collect
             (if (cdr mails)
                 (helm-comp-read "Choose mail: " mails)
                 (bbdb-mail-address (car i))))))

(defun helm-bbdb-compose-mail (candidate)
  "Compose a mail with all records of bbdb buffer."
  (helm-bbdb-view-person-action candidate)
  (let* ((address-list (helm-bbdb-collect-mail-addresses))
         (address-str  (mapconcat 'identity address-list ",\n    ")))
    ;; Delete the bbdb window and its buffer.
    (quit-window t (get-buffer-window bbdb-buffer-name))
    (compose-mail address-str nil nil nil 'switch-to-buffer)))

(defun helm-bbdb-delete-contact (candidate)
  "Delete CANDIDATE from the bbdb buffer and database.
Prompt user to confirm deletion."
  (bbdb-redisplay-record (helm-bbdb-get-record candidate))
  (with-current-buffer bbdb-buffer-name
    (let ((field (bbdb-current-field))
          (record (bbdb-current-record)))
      (bbdb-delete-field-or-record record field)
      (delete-window)
      (message "%s (deleted)" candidate))))

(defun helm-bbdb-copy-mail-address (candidate)
  "Add CANDIDATE's email address to the kill ring."
  (helm-bbdb-view-person-action candidate)
  (let* ((address-list (helm-bbdb-collect-mail-addresses))
         (address-str  (mapconcat 'identity address-list ",\n    ")))
    (delete-window)
    (kill-new address-str)
    (message "%s (copied)" address-str)))

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
