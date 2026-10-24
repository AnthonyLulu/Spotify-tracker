#!/usr/bin/env bash
# Operator-only encrypted staging backup + disposable LOCAL restore.
# NEVER targets production; it never drops or alters existing staging data.
set -Eeuo pipefail
umask 077
die(){ printf 'BACKUP NOT VERIFIED: %s\n' "$1" >&2; exit 2; }
for cmd in supabase psql age tar sha256sum node mktemp; do
 command -v "$cmd" >/dev/null 2>&1 || die "Missing local command: $cmd"
done
for var in CB_E2E_DB_URL CB_E2E_RESTORE_TEST_DB_URL CB_BACKUP_AGE_RECIPIENT CB_E2E_BACKUP_DIR; do
 [[ -n "$(printenv "$var" || true)" ]] || die "Set $var in a private local shell environment"
done
if [[ -n "${CB_BACKUP_AGE_IDENTITY_FILE:-}" ]]; then
 [[ -f "$CB_BACKUP_AGE_IDENTITY_FILE" ]] || die "Age private-key file unavailable"
fi
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
 AND (SELECT count(*) FROM cb_e2e_reconstruction_20261010.synthetic_adult_seed_v1)=24435
 AND (SELECT count(*) FROM cb_e2e_reconstruction_20261010.synthetic_adult_attributes_v1)=24435
 AND (SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1)=26456
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
# Detect mutations across separate role/schema/data dump connections. Hash all
# rows of 26 critical tables, order-independent and deterministic on Postgres 17.
# This is deliberately more expensive than row counts and is NOT a full DB digest.
fingerprint_sql_1="$(cat <<'FINGERPRINT_SQL_1'
WITH key_checks AS (
 SELECT 'players' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.players v) hashed) AS fingerprint
 UNION ALL
 SELECT 'tournaments' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.tournaments v) hashed) AS fingerprint
 UNION ALL
 SELECT 'matches' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_tournament_matches v) hashed) AS fingerprint
 UNION ALL
 SELECT 'points' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_ranking_points v) hashed) AS fingerprint
 UNION ALL
 SELECT 'week_jobs' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'week_items' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.world_week_items_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'checkpoint_players' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_checkpoint_20261010.players v) hashed) AS fingerprint
 UNION ALL
 SELECT 'frozen_synthetic_players' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.synthetic_adult_seed_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'frozen_synthetic_attributes' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.synthetic_adult_attributes_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'initial_rank_assignments' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'historical_atp_reference' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.atp_20251201_reference_v1 v) hashed) AS fingerprint
 UNION ALL
 SELECT 'historical_atp_bridge' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
  FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM cb_e2e_reconstruction_20261010.atp_2025_ledger_bridge_v1 v) hashed) AS fingerprint
)
SELECT jsonb_object_agg(check_key,fingerprint ORDER BY check_key)::text FROM key_checks;
FINGERPRINT_SQL_1
)"
fingerprint_sql_2="$(cat <<'FINGERPRINT_SQL_2'
WITH key_checks AS (
 SELECT 'court_boss_match_stat_lines' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.court_boss_match_stat_lines v) hashed) AS fingerprint
 UNION ALL
 SELECT 'player_titles' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.player_titles v) hashed) AS fingerprint
 UNION ALL
 SELECT 'ranking_history' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.ranking_history v) hashed) AS fingerprint
 UNION ALL
 SELECT 'world_tournament_simulations' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_tournament_simulations v) hashed) AS fingerprint
 UNION ALL
 SELECT 'world_tournament_qualifying_entries' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_tournament_qualifying_entries v) hashed) AS fingerprint
 UNION ALL
 SELECT 'world_qualifying_acceptance_entries' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_qualifying_acceptance_entries v) hashed) AS fingerprint
 UNION ALL
 SELECT 'player_training_load_profiles' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.player_training_load_profiles v) hashed) AS fingerprint
)
SELECT jsonb_object_agg(check_key,fingerprint ORDER BY check_key)::text FROM key_checks;
FINGERPRINT_SQL_2
)"
fingerprint_sql_3="$(cat <<'FINGERPRINT_SQL_3'
WITH key_checks AS (
 SELECT 'injuries' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.injuries v) hashed) AS fingerprint
 UNION ALL
 SELECT 'record_occurrences' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.record_occurrences v) hashed) AS fingerprint
 UNION ALL
 SELECT 'court_boss_world_story_log' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.court_boss_world_story_log v) hashed) AS fingerprint
 UNION ALL
 SELECT 'news_items' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.news_items v) hashed) AS fingerprint
 UNION ALL
 SELECT 'finance_transactions' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.finance_transactions v) hashed) AS fingerprint
 UNION ALL
 SELECT 'player_tournament_history' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.player_tournament_history v) hashed) AS fingerprint
 UNION ALL
 SELECT 'world_qualifying_states' AS check_key,
 (SELECT md5(coalesce(string_agg(row_md5,'' ORDER BY row_md5),''))
 FROM (SELECT md5(to_jsonb(v)::text) AS row_md5 FROM public.world_qualifying_states v) hashed) AS fingerprint
)
SELECT jsonb_object_agg(check_key,fingerprint ORDER BY check_key)::text FROM key_checks;
FINGERPRINT_SQL_3
)"
stage_or_restored_fingerprints(){
 local dest="$1" f1 f2 f3
 f1="$(psql "$dest" -XAtq -v ON_ERROR_STOP=1 -c "$fingerprint_sql_1")" || return 1
 f2="$(psql "$dest" -XAtq -v ON_ERROR_STOP=1 -c "$fingerprint_sql_2")" || return 1
 f3="$(psql "$dest" -XAtq -v ON_ERROR_STOP=1 -c "$fingerprint_sql_3")" || return 1
 node -e 'const p=process.argv.slice(1).map(JSON.parse);const all=Object.assign({},...p);if(Object.keys(all).length!==26||Object.values(all).some(x=>typeof x!=="string"||!/^[0-9a-f]{32}$/.test(x)))process.exit(3);process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(all).sort(([a],[b])=>a.localeCompare(b)))))' "$f1" "$f2" "$f3"
}

before_fingerprint="$(stage_or_restored_fingerprints "$CB_E2E_DB_URL")" || die 'Cannot fingerprint isolated stage before dump'
[[ -n "$before_fingerprint" ]] || die 'Empty initial stage fingerprint'
supabase db dump --db-url "$CB_E2E_DB_URL" --role-only --file "$tmp/roles.sql" >/dev/null
supabase db dump --db-url "$CB_E2E_DB_URL" --schema "$schemas" --file "$tmp/schema.sql" >/dev/null
supabase db dump --db-url "$CB_E2E_DB_URL" --schema "$schemas" --data-only --use-copy --file "$tmp/data.sql" >/dev/null
for file in roles.sql schema.sql data.sql; do
 [[ -s "$tmp/$file" ]] || die "Empty stage dump: $file"
done
after_dump_fingerprint="$(stage_or_restored_fingerprints "$CB_E2E_DB_URL")" || die 'Cannot fingerprint isolated stage after dump'
[[ "$before_fingerprint" == "$after_dump_fingerprint" ]] || die 'Stage changed during multi-session export; do NOT trust or restore this dump'
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
 'checkpoint_players',(SELECT count(*) FROM cb_e2e_checkpoint_20261010.players),
 'frozen_synthetic_players',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.synthetic_adult_seed_v1),
 'frozen_synthetic_attributes',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.synthetic_adult_attributes_v1),
 'initial_rank_assignments',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1),
 'historical_atp_reference',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.atp_20251201_reference_v1),
 'historical_atp_bridge',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.atp_2025_ledger_bridge_v1),
 'court_boss_match_stat_lines',(SELECT count(*) FROM public.court_boss_match_stat_lines),
 'player_titles',(SELECT count(*) FROM public.player_titles),
 'ranking_history',(SELECT count(*) FROM public.ranking_history),
 'world_tournament_simulations',(SELECT count(*) FROM public.world_tournament_simulations),
 'world_tournament_qualifying_entries',(SELECT count(*) FROM public.world_tournament_qualifying_entries),
 'world_qualifying_acceptance_entries',(SELECT count(*) FROM public.world_qualifying_acceptance_entries),
 'player_training_load_profiles',(SELECT count(*) FROM public.player_training_load_profiles),
 'injuries',(SELECT count(*) FROM public.injuries),
 'record_occurrences',(SELECT count(*) FROM public.record_occurrences),
 'court_boss_world_story_log',(SELECT count(*) FROM public.court_boss_world_story_log),
 'news_items',(SELECT count(*) FROM public.news_items),
 'finance_transactions',(SELECT count(*) FROM public.finance_transactions),
 'player_tournament_history',(SELECT count(*) FROM public.player_tournament_history),
 'world_qualifying_states',(SELECT count(*) FROM public.world_qualifying_states)
)::text;"
before="$(psql "$CB_E2E_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$counts")" || die 'Stage validation read failed'
after="$(psql "$CB_E2E_RESTORE_TEST_DB_URL" -XAtq -v ON_ERROR_STOP=1 -c "$counts")" || die 'Restore validation read failed'
[[ "$before" == "$after" ]] || die 'Critical game table counts differ after local restore'
restored_fingerprint="$(stage_or_restored_fingerprints "$CB_E2E_RESTORE_TEST_DB_URL")" || die 'Cannot fingerprint independently restored local database'
[[ "$before_fingerprint" == "$restored_fingerprint" ]] || die 'Critical seed, event, physiology, record or checkpoint contents mismatch after local restore'
printf '%s\n' "$restored_fingerprint" > "$tmp/RESTORED_DIGESTS.json"
printf '%s\n' "$after" > "$tmp/RESTORED_COUNTS.json"
printf '%s\n' 'Twelve critical game/seed/checkpoint table counts match; NOT a full cross-table digest or gameplay certificate.' > "$tmp/VALIDATION.txt"
out="$CB_E2E_BACKUP_DIR/court-boss-e2e-$(date -u +%Y%m%dT%H%M%SZ).tar.age"
tar -C "$tmp" -cf - roles.sql schema.sql data.sql SHA256SUMS RESTORED_COUNTS.json RESTORED_DIGESTS.json VALIDATION.txt |
 age -r "$CB_BACKUP_AGE_RECIPIENT" -o "$out"
[[ -s "$out" ]] || die 'Encrypted backup missing'
if [[ -n "${CB_BACKUP_AGE_IDENTITY_FILE:-}" ]]; then
 age -d -i "$CB_BACKUP_AGE_IDENTITY_FILE" "$out" | tar -tf - | grep -Fx 'SHA256SUMS' >/dev/null || die 'Archive decrypt check failed'
else
 # Public-recipient-only CI mode. Offline owner retains the private age key.
 # Successful copy/restore and checksums DO NOT verify encrypted decryption.
 printf 'OFFLINE PRIVATE-KEY CHECK STILL REQUIRED: %s\\n' "$out" >&2
fi
sha256sum "$out" > "$out.sha256"
chmod 600 "$out" "$out.sha256"
printf 'BACKUP VERIFIED: %s\n' "$out"
printf 'Keep archive and private decryption key separately. No staging reset authorized.\n'
