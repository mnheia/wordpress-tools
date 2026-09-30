#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SITE_NAME="${SITE_NAME:-example.com}"
WP_ROOT="${WP_ROOT:-/var/www/${SITE_NAME}}"
WEBROOT="${WEBROOT:-${WP_ROOT}/public_html}"
DB_NAME="${DB_NAME:-wordpress}"
BACKUP_BASE="${BACKUP_BASE:-/var/backups/wordpress}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

DATE="${DATE:-$(date +%Y%m%d)}"
BACKUP_DIR="${BACKUP_BASE}/${SITE_NAME}-${DATE}"
ARCHIVE="${BACKUP_DIR}.tar.gz"
LOCK="${LOCK:-/run/lock/backup-wordpress.lock}"

exec 200>"$LOCK"
flock -n 200 || {
  echo "Another WordPress backup is already running. Exiting."
  exit 0
}

for cmd in rsync mysqldump tar find flock; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  }
done

[ -d "$WEBROOT" ] || {
  echo "ERROR: WEBROOT not found: $WEBROOT" >&2
  exit 1
}

mkdir -p "$BACKUP_BASE"
rm -rf "$BACKUP_DIR"

cleanup() {
  rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

echo "Starting WordPress backup for $SITE_NAME: $DATE"

mkdir -p "$BACKUP_DIR/files"

echo "Copying website files..."
rsync -a --exclude="backups" "$WEBROOT/" "$BACKUP_DIR/files/"

echo "Dumping MySQL/MariaDB database..."
mysqldump --single-transaction --quick "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}.sql"

echo "Compressing backup..."
tar -czf "$ARCHIVE" -C "$BACKUP_BASE" "${SITE_NAME}-${DATE}"

rm -rf "$BACKUP_DIR"
trap - EXIT

echo "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_BASE" -type f -name "${SITE_NAME}-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete

echo "Backup finished successfully: $ARCHIVE"
