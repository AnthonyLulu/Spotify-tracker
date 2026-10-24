#!/usr/bin/env bash
# Operator-only encrypted staging backup + disposable LOCAL restore.
# NEVER targets production; it never drops or alters existing staging data.
set -Eeuo pipefail
umask 077
die(){ printf 'BACKUP NOT VERIFIED: %s\n' "$1" >&2; exit 2; }
for cmd in supabase psql age tar sha256sum node mktemp; do
 command -v "$cmd" >/dev/null 2>&1 || die "Missing local command: $cmd"
done
for var in CB_E2E_DB_URL CB_E2E_RESTORE_TEST_DB_URL CB_BACKUP_AGE_RECIPIENT CB_BACKUP_AGE_IDENTITY_FILE CB_E2E_BACKUP_DIR; do
 [[ -n "$(printenv "$var" || true)" ]] || die "Set $var in a private local shell environment"
done
[[ -f "$CB_BACKUP_AGE_IDENTITY_FILE" ]] || die "Age private-key file unavailable"
# URLs remain in operator-only process arguments, never printed or committed.
node <<'NODE' || die 'Unsafe source or target connection URL'
const a=new URL(process.env.CB_E2E_DB_URL);
const b=new URL(process.env.CB_E2E_RESTORE_TEST_DB_URL);
if (!/^postgres(ql)?:$/.test(a.protocol)||!/^postgres(ql)?:$/.test(b.protocol))
 throw Error('PostgreSQL URLs required');
if (!/(^|\.)sozrygjxjotozrsenred\.supabase\.co$/.test(a.hostname) &&
    !(a.hostname.endsWith('.pooler.supabase.com') && a.username.includes('sozrygjxjotozrsenred')))
 throw Error('Only isolated staging is permitted');
if (!['localhost','127.0.0.1','[::1]'].includes(b.hostname))
 throw Error('Restore must target a local test database');
if (!/^\/cb_e2e_restore_[a-z0-9_]+$/.test(b.pathname))
 throw Error('Local scratch database must start cb_e2e_restore_');
NODE
source_guard="SELECT CASE WHEN
 to_regclass('cb_e2e_checkpoint_20261010.players') IS NOT NULL
 AND to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NOT NULL
 AND (SELECT count(*) FROM public.game_saves)=0
 AND (SELECT count(*) FROM public.game_save_slots)=0
 AND (SELECT count(*) FROM public.career_state)=0
 THEN 'OK' ELSE 'UNSAFE' END;"
guard="$(psql "$CB_E2E_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$source_guard")" || die 'Cannot inspect stage'
[[ "$guard" == OK ]] || die 'Isolated checkpoint / zero-save guard failed'
target_guard="SELECT CASE WHEN
 (SELECT count(*) FROM pg_tables WHERE schemaname IN ('cb_e2e_checkpoint_20261010','cb_e2e_reconstruction_20261010','court_boss_private'))=0
 AND to_regclass('public.players') IS NULL
 THEN 'EMPTY' ELSE 'NOT_EMPTY' END;"
target="$(psql "$CB_E2E_RESTORE_TEST_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$target_guard")" || die 'Cannot inspect scratch DB'
[[ "$target" == EMPTY ]] || die 'Refuse to overwrite non-empty scratch database'
mkdir -p "$CB_E2E_BACKUP_DIR"
chmod 700 "$CB_E2E_BACKUP_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"
schemas="public,court_boss_private,cb_e2e_checkpoint_20261010,cb_e2e_reconstruction_20261010"
# Supabase CLI skips platform-owned schemas such as auth and storage.
supabase db dump --db-url "$CB_E2E_DB_URL" --role-only --file "$tmp/roles.sql" >/dev/null
supabase db dump --db-url "$CB_E2E_DB_URL" --schema "$schemas" --file "$tmp/schema.sql" >/dev/null
supabase db dump --db-url "$CB_E2E_DB_URL" --schema "$schemas" --data-only --use-copy --file "$tmp/data.sql" >/dev/null
for file in roles.sql schema.sql data.sql; do
 [[ -s "$tmp/$file" ]] || die "Empty stage dump: $file"
done
(cd "$tmp" && sha256sum roles.sql schema.sql data.sql > SHA256SUMS)
# Run on a fresh LOCAL Supabase/Postgres 17 scratch DB with needed extensions.
# Retain roles for archival, but do not import global roles into test DB.
psql "$CB_E2E_RESTORE_TEST_DB_URL" -X -v ON_ERROR_STOP=1 --single-transaction \
 -f "$tmp/schema.sql" -c 'SET session_replication_role=replica' \
 -f "$tmp/data.sql" >/dev/null || die 'Local restore failed'
counts="SELECT json_build_object(
 'players',(SELECT count(*) FROM public.players),
 'tournaments',(SELECT count(*) FROM public.tournaments),
 'matches',(SELECT count(*) FROM public.world_tournament_matches),
 'points',(SELECT count(*) FROM public.world_ranking_points),
 'week_jobs',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1),
 'week_items',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_items_v1),
 'checkpoint_players',(SELECT count(*) FROM cb_e2e_checkpoint_20261010.players)
)::text;"
before="$(psql "$CB_E2E_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$counts")" || die 'Stage validation read failed'
after="$(psql "$CB_E2E_RESTORE_TEST_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$counts")" || die 'Restore validation read failed'
[[ "$before" == "$after" ]] || die 'Critical game table counts differ after local restore'
printf '%s\n' "$after" > "$tmp/RESTORED_COUNTS.json"
printf '%s\n' 'Critical-table counts match; this is NOT an E2E or full cross-table digest certificate.' > "$tmp/VALIDATION.txt"
out="$CB_E2E_BACKUP_DIR/court-boss-e2e-$(date -u +%Y%m%dT%H%M%SZ).tar.age"
tar -C "$tmp" -cf - roles.sql schema.sql data.sql SHA256SUMS RESTORED_COUNTS.json VALIDATION.txt |
 age -r "$CB_BACKUP_AGE_RECIPIENT" -o "$out"
[[ -s "$out" ]] || die 'Encrypted backup missing'
age -d -i "$CB_BACKUP_AGE_IDENTITY_FILE" "$out" | tar -tf - | grep -Fxq 'SHA256SUMS' || die 'Archive decrypt check failed'
sha256sum "$out" > "$out.sha256"
chmod 600 "$out" "$out.sha256"
printf 'BACKUP VERIFIED: %s\n' "$out"
printf 'Keep archive and private decryption key separately. No staging reset authorized.\n'
