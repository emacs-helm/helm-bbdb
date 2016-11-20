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
