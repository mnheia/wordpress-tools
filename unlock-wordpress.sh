#!/bin/sh
set -eu

WP_ROOT="${WP_ROOT:-/var/www/example.com}"
WEBROOT="${WEBROOT:-${WP_ROOT}/public_html}"

WEBUSER="${WEBUSER:-www-data}"
WEBGROUP="${WEBGROUP:-www-data}"

CODE_OWNER_USER="${CODE_OWNER_USER:-root}"

RUNTIME_DIRS="
wp-content/uploads
wp-content/cache
wp-content/upgrade
wp-content/languages
wp-content/languages/loco
wp-content/languages/loco/plugins
wp-content/uploads/wc-logs
wp-content/wflogs
wp-content/logs
wp-content/update-temp-backup
wp-content/upgrade-temp-backup
"

DROPIN_FILES="
wp-content/object-cache.php
wp-content/advanced-cache.php
wp-content/db.php
wp-content/sunrise.php
"

msg() {
  printf "%s\n" "$*"
}

ensure_dir() {
  [ -d "$1" ] || install -d -m 755 "$1"
}

safe_chmod_dirfile() {
  [ -e "$1" ] || return 0
  find "$1" -type d -exec chmod 755 {} \;
  find "$1" -type f -exec chmod 644 {} \;
}

set_core_owner() {
  owner_user="$1"
  owner_group="$2"

  for d in wp-admin wp-includes; do
    if [ -d "$WEBROOT/$d" ]; then
      chown -R "$owner_user:$owner_group" "$WEBROOT/$d"
    fi
  done

  for f in "$WEBROOT"/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "wp-content" ] && continue
    [ "$base" = ".well-known" ] && continue
    chown "$owner_user:$owner_group" "$f" 2>/dev/null || true
  done
}

set_dropin_owner_unlocked() {
  for rel in $DROPIN_FILES; do
    f="$WEBROOT/$rel"
    [ -f "$f" ] || continue
    chown "$WEBUSER:$WEBGROUP" "$f"
    chmod 644 "$f"
  done
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

[ -d "$WEBROOT" ] || {
  echo "WEBROOT not found: $WEBROOT" >&2
  exit 1
}

msg "[1/10] Ensuring runtime directories exist..."
for rel in $RUNTIME_DIRS; do
  ensure_dir "$WEBROOT/$rel"
done

msg "[2/10] Securing wp-config.php outside webroot..."
WPCFG="$WP_ROOT/wp-config.php"
if [ -f "$WPCFG" ]; then
  chown "$CODE_OWNER_USER:$WEBGROUP" "$WPCFG"
  chmod 640 "$WPCFG"
else
  msg " - Notice: $WPCFG not found, skipping."
fi

msg "[3/10] Setting baseline ownership..."
chown -R "$CODE_OWNER_USER:$CODE_OWNER_USER" "$WEBROOT"

msg "[4/10] Granting web write access to runtime directories..."
for rel in $RUNTIME_DIRS; do
  [ -d "$WEBROOT/$rel" ] || continue
  chown -R "$WEBUSER:$WEBGROUP" "$WEBROOT/$rel"
done

THEMES_DIR="$WEBROOT/wp-content/themes"
PLUGINS_DIR="$WEBROOT/wp-content/plugins"

ensure_dir "$THEMES_DIR"
ensure_dir "$PLUGINS_DIR"

msg "[5/10] Unlocking themes and plugins for updates..."
chown -R "$WEBUSER:$WEBGROUP" "$THEMES_DIR" "$PLUGINS_DIR"

msg "[6/10] Unlocking WordPress core for updates..."
set_core_owner "$WEBUSER" "$WEBGROUP"

msg "[7/10] Enforcing standard file permissions..."
for path in \
  "$WEBROOT/wp-admin" \
  "$WEBROOT/wp-includes" \
  "$WEBROOT/wp-content/uploads" \
  "$WEBROOT/wp-content/cache" \
  "$WEBROOT/wp-content/upgrade" \
  "$WEBROOT/wp-content/languages" \
  "$WEBROOT/wp-content/wflogs" \
  "$WEBROOT/wp-content/logs" \
  "$THEMES_DIR" \
  "$PLUGINS_DIR"
do
  safe_chmod_dirfile "$path"
done

msg "[8/10] Unlocking wp-content top-level directory..."
if [ -d "$WEBROOT/wp-content" ]; then
  chown "$WEBUSER:$WEBGROUP" "$WEBROOT/wp-content"
  chmod 755 "$WEBROOT/wp-content"
fi

msg "[9/10] Unlocking WordPress drop-ins..."
set_dropin_owner_unlocked

msg "[10/10] Verification summary..."
ls -ld "$WEBROOT" \
       "$WEBROOT/wp-content" \
       "$WEBROOT/wp-content/plugins" \
       "$WEBROOT/wp-content/themes" \
       "$WEBROOT/wp-content/uploads" \
       "$WPCFG" 2>/dev/null || true

msg "Done. Current mode: UNLOCKED / UPDATE-CAPABLE"
msg "WordPress core, themes, plugins and drop-ins are writable by $WEBUSER."
msg "If WordPress writes files directly, wp-config.php may need: define('FS_METHOD','direct');"
