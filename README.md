[![MELPA](http://melpa.milkbox.net/packages/helm-bbdb-badge.svg)](http://melpa.milkbox.net/#/helm-bbdb)
[![MELPA Stable](https://stable.melpa.org/packages/helm-bbdb-badge.svg)](https://stable.melpa.org/#/helm-bbdb)

# helm-bbdb

A Helm interface for BBDB, the Insidious Big Brother Database for GNU Emacs.

# Features

* List all contacts in the bbdb database.
* Match name, email or organization.
* Send email to one or more contacts (marked).
* Display one or more contacts in the bbdb buffer (marked).
* Record new contacts.
* Delete one or more contacts (marked).
* Support auto-completion in message-mode buffers.

# Dependencies

[helm](https://github.com/emacs-helm/helm) and [bbdb](http://melpa.milkbox.net/#/bbdb)

# Install

## From source

```elisp
(add-to-list 'load-path "/path/to/helm-bbdb")
(autoload 'helm-bbdb "helm-bbdb.el" nil t)
```

## From melpa

Just install from Melpa and once `(package-initialize)` loads and activates the package, `helm-bbdb` should be available.

# Configuration

To use address auto-completion in message-mode buffers with TAB, add `helm-bbdb-expand-name` to the `message-completion-alist` variable.

# Related project

[Addressbook bookmark](https://github.com/thierryvolpiatto/addressbook-bookmark) is a contact manager for emacs similar to `bbdb` but much lighter (only one file `addressbook-bookmark.el`) and without all the `bbdb` features you will never use. It provides completion in message-mode buffers using the helm interface, which is how helm works out of the box with M-x `helm-addressbook-bookmarks`.  Contacts are stored in emacs bookmark file, which means the database format is much simpler and lighter than `bbdb`'s database.
