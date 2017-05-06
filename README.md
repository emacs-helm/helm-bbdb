[![MELPA](http://melpa.milkbox.net/packages/helm-bbdb-badge.svg)](http://melpa.milkbox.net/#/helm-bbdb)
[![MELPA Stable](https://stable.melpa.org/packages/helm-bbdb-badge.svg)](https://stable.melpa.org/#/helm-bbdb)

# helm-bbdb

A Helm interface for bbdb.

# Features

* List all contacts in bbdb database.
* Match name, email or organization.
* Allow sending email to one or more contact (marked).
* Show one or more contact (marked) in bbdb buffer.
* Allow recording new contacts.
* Allow deleting one or more contacts (marked).
* Allow copying email address of current contact (selection).

# Dependencies

[helm](https://github.com/emacs-helm/helm) and [bbdb](http://melpa.milkbox.net/#/bbdb)

# Install

## From source

```elisp
(add-to-list 'load-path "/path/to/helm-bbdb")
(autoload 'helm-bbdb "helm-bbdb.el" nil t)
```

## From melpa

Just install from Melpa and once `(package-initialize)` `helm-bbdb` should be available.

# Related project

[Addressbook bookmark](https://github.com/thierryvolpiatto/addressbook-bookmark) is
a contact manager for emacs similar to `bbdb` but much more light (only
one file `addressbook-bookmark.el`) without all the `bbdb` features you
will never use. 
It provide completion in email buffers, its helm
interface which is part of helm works out of the box with M-x
`helm-addressbook-bookmarks`.  Contacts are stored in emacs bookmark
file, so the database format is also much simpler and lighter than `bbdb`
one.
