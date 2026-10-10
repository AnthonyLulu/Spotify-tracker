#!/usr/bin/env bash
# Secure operator-only export. Read-only in both databases. Never runs on GitHub PR CI.
set -Eeuo pipefail
umask 077
if [[ -z "${CB_PROD_DB_URL:-}" || -z "${CB_E2E_DB_URL:-}" ]]; then
 echo "Provide CB_PROD_DB_URL and CB_E2E_DB_URL through your secure environment, not on the CLI or in git." >&2
 exit 2
fi
for cmd in psql pg_dump node; do
 command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 2; }
done
base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$base/.private-artifacts/2050-schema}"
mkdir -p "$out"
chmod 700 "$out"
# These SELECT-only inventories contain object names + definition hashes, never rows.
psql "$CB_PROD_DB_URL" -X -A -t -q -v ON_ERROR_STOP=1 \
 -f "$base/qa/world-2050/schema-inventory.sql" > "$out/production.json"
psql "$CB_E2E_DB_URL" -X -A -t -q -v ON_ERROR_STOP=1 \
 -f "$base/qa/world-2050/schema-inventory.sql" > "$out/isolated.json"
# Schema-only pg_dump is essential: catalogs cannot safely reproduce extension,
# DDL dependency order, RLS, grants, triggers and function security on their own.
# This file may contain privileged SQL function source; never commit it or publish it.
pg_dump "$CB_PROD_DB_URL" --schema-only --no-owner \
 --schema=public --schema=court_boss_private \
 --file="$out/production-schema.PRIVATE.sql"
node "$base/scripts/cb-schema-audit.mjs" \
 "$out/production.json" "$out/isolated.json" "$out/schema-diff.json"
