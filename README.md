[![MELPA](https://melpa.org/packages/helm-bbdb-badge.svg)](https://melpa.org/#/helm-bbdb)
[![MELPA Stable](https://stable.melpa.org/packages/helm-bbdb-badge.svg)](https://stable.melpa.org/#/helm-bbdb)

# helm-bbdb

A Helm interface for BBDB, the Insidious Big Brother Database for GNU
Emacs.

## Features

* List all contacts in the bbdb database.
* Match name, email or organization.
* Send email to one or more contacts (marked).
* Display one or more contacts in the bbdb buffer (marked).
* Record new contacts.
* Delete one or more contacts (marked).
* Support auto-completion in `message-mode` buffers.

## Dependencies

[Helm](https://github.com/emacs-helm/helm) and
[BBDB](https://melpa.org/#/bbdb)

## Installation

### From source

```elisp
(add-to-list 'load-path "/path/to/helm-bbdb")
(autoload 'helm-bbdb "helm-bbdb.el" nil t)
```

### From MELPA

Install `helm-bbdb` from MELPA. Once the package is installed and
activated, the `helm-bbdb` command should be available.

## Configuration

To use address auto-completion in `message-mode` buffers with TAB, add
`helm-bbdb-expand-name` to the `message-completion-alist` variable.

## Address editing

`bbdb-edit-field` and `bbdb-insert-field` can edit BBDB addresses with
Helm completion enabled. When editing address fields, `helm-bbdb` adds
explicit completion candidates for values that BBDB normally reads as
an empty string:

* `[End street lines]` ends the repeated street-line prompt.
* `[Leave blank]` stores an empty value for city, state, postcode, or
  country.

These candidates avoid the need to disable Helm completion for BBDB
address editing commands when the corresponding BBDB completion lists
are non-empty.

## Related project

[Addressbook
bookmark](https://github.com/thierryvolpiatto/addressbook-bookmark) is
a contact manager for Emacs similar to `BBDB` but much lighter (only
one file `addressbook-bookmark.el`) and without all the `bbdb`
features you will never use. It provides completion in `message-mode`
buffers using the helm interface, which is how helm works out of the
box with `M-x helm-addressbook-bookmarks`. Contacts are stored in
emacs bookmark file, which means the database format is much simpler
and lighter than `bbdb`'s database.
