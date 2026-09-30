Copyright (c) 2026, Mnheia <mnheia@gmail.com>

# wordpress-tools
Small Bash utilities for WordPress backups and switching file ownership between hardened and update-capable modes.

## Scripts

### backup-wordpress.sh
Creates a compressed backup containing the WordPress files and a MySQL/MariaDB dump, then removes old archives according to the configured retention period.

Configuration can be supplied through environment variables:

- `SITE_NAME`
- `WP_ROOT`
- `WEBROOT`
- `DB_NAME`
- `BACKUP_BASE`
- `RETENTION_DAYS`

Example:

```bash
SITE_NAME=example.com \
WP_ROOT=/var/www/example.com \
DB_NAME=wordpress \
BACKUP_BASE=/var/backups/wordpress \
./backup-wordpress.sh
```

Database credentials are intentionally not stored in the script. Use the normal MySQL/MariaDB client configuration, for example a protected `/root/.my.cnf`.

### lock-wordpress.sh
Switches a WordPress installation into a hardened ownership model:

- WordPress core code is root-owned.
- Themes and plugins are root-owned.
- Runtime directories such as uploads, cache, logs and upgrade directories remain writable by the web server.
- Common WordPress drop-in files are root-owned.
- `wp-config.php`, when stored one level above the webroot, is restricted to mode `0640`.
- Selected generated webroot files such as `llms.txt` can remain web-writable.

This reduces the amount of PHP code that the web-server account can modify during normal operation.

### unlock-wordpress.sh
Temporarily makes WordPress core, themes, plugins and drop-ins writable by the web-server account so WordPress can perform updates.

After updates complete, run `lock-wordpress.sh` again.


### find-recent-files.sh
Shows recently changed files inside a WordPress webroot using both file modification time (`mtime`) and metadata change time (`ctime`).

This is useful after plugin/core updates, permission changes or when troubleshooting which files WordPress or a plugin is actively modifying.

Defaults:

- `WEBROOT=/var/www/example.com/public_html`
- `MINUTES=15`
- `LIMIT=200`

Example:

```bash
WEBROOT=/var/www/example.com/public_html \
MINUTES=60 \
LIMIT=100 \
./find-recent-files.sh
```

## Layout
The default example layout is:

```text
/var/www/example.com/
├── wp-config.php
└── public_html/
    ├── wp-admin/
    ├── wp-content/
    └── wp-includes/
```

Override `WP_ROOT` and `WEBROOT` if your installation is laid out differently.

## Requirements
Depending on the script:

- Bash or POSIX shell
- `rsync`
- `mysqldump`
- `tar`
- `find`
- `flock`
- standard GNU/Linux ownership/permission tools

The lock/unlock scripts must run as root.

## Important
The hardened ownership model is intentionally opinionated. Review it against your plugins, cache solution, translation tooling and deployment method before using it.

Some WordPress plugins generate or modify PHP drop-ins under `wp-content`. If a specific drop-in must remain writable during normal operation, adapt the script deliberately rather than making the whole WordPress tree writable.

## Bugs
Please report bugs or feature requests through the web interface at https://github.com/mnheia/wordpress-tools/issues
