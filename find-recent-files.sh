#!/usr/bin/env bash
set -Eeuo pipefail

WEBROOT="${WEBROOT:-/var/www/example.com/public_html}"
MINUTES="${MINUTES:-15}"
LIMIT="${LIMIT:-200}"

if [ ! -d "$WEBROOT" ]; then
  echo "ERROR: WEBROOT not found: $WEBROOT" >&2
  exit 1
fi

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]] || [ "$MINUTES" -lt 1 ]; then
  echo "ERROR: MINUTES must be a positive integer." >&2
  exit 1
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ]; then
  echo "ERROR: LIMIT must be a positive integer." >&2
  exit 1
fi

echo "== Files by mtime (modified in last ${MINUTES}m) =="
find "$WEBROOT" -type f -mmin "-$MINUTES" \
  -printf '%T@ %TY-%Tm-%Td %TH:%TM:%S %u:%g %m size=%s %p\n' \
  | sort -nr \
  | cut -d' ' -f2- \
  | head -n "$LIMIT"

echo
echo "== Files by ctime (metadata changed in last ${MINUTES}m) =="
find "$WEBROOT" -type f -cmin "-$MINUTES" \
  -printf '%C@ %CY-%Cm-%Cd %CH:%CM:%CS %u:%g %m size=%s %p\n' \
  | sort -nr \
  | cut -d' ' -f2- \
  | head -n "$LIMIT"
