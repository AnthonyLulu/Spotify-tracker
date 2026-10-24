import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const clean=readFileSync(new URL('../qa/world-2050/stage-clean-week-plan-v111.sql',import.meta.url),'utf8');
const drift=readFileSync(new URL('../qa/world-2050/stage-original-player-drift-v111.sql',import.meta.url),'utf8');
const backup=readFileSync(new URL('../scripts/cb-stage-independent-backup-verify.sh',import.meta.url),'utf8');
test('calendar replay derives historical 12-week fixture eligibility without writes',()=>{
 assert.match(clean,/BEGIN READ ONLY;/);
 assert.match(clean,/generate_series\(date '2026-01-04',date '2026-03-22'/);
 assert.match(clean,/public\.tournament_format_rules/);
 assert.match(clean,/cancelled\|canceled\|postponed\|abandoned/);
 assert.match(clean,/invalid_already_played/);
 assert.match(clean,/invalid_not_played/);
 assert.match(clean,/'may_write_results',false/);
 assert.match(clean,/'external_restored_backup_verified',false/);
 assert.doesNotMatch(clean,/\b(?:CREATE|INSERT|UPDATE|DELETE|TRUNCATE|DROP|ALTER)\s+(?:INTO\s+|FROM\s+)?(?:public|cb_e2e_reconstruction_20261010)\./i);
});
test('checkpoint drift explicitly distinguishes changed physiology/rank from missing identities',()=>{
 assert.match(drift,/BEGIN READ ONLY;/);
 assert.match(drift,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(drift,/public\.players/);
 assert.match(drift,/original_players_missing/);
 assert.match(drift,/rank_drift/);
 assert.match(drift,/fatigue_drift/);
 assert.match(drift,/'safe_to_restore_individual_rows',false/);
 assert.match(drift,/'world_2050_certified',false/);
});
test('external backup double checks twenty-six tables in three bounded hash groups',()=>{
 assert.match(backup,/fingerprint_sql_1=/);
 assert.match(backup,/fingerprint_sql_2=/);
 assert.match(backup,/fingerprint_sql_3=/);
 assert.match(backup,/stage_or_restored_fingerprints/);
 assert.match(backup,/before_fingerprint=/);
 assert.match(backup,/after_dump_fingerprint=/);
 assert.match(backup,/restored_fingerprint=/);
 assert.match(backup,/Stage changed during multi-session export/);
 assert.match(backup,/Critical player\/seed\/match\/checkpoint contents mismatch/);
 assert.match(backup,/RESTORED_DIGESTS\.json/);
 assert.match(backup,/md5\(to_jsonb\(v\)::text\)/);
 assert.match(backup,/string_agg\(row_md5,'' ORDER BY row_md5\)/);
 for(const required of ['public.players','public.world_tournament_matches','public.world_ranking_points',
  'cb_e2e_checkpoint_20261010.players','synthetic_adult_seed_v1',
  'synthetic_adult_attributes_v1','world_rank_seed_plan_v1','atp_20251201_reference_v1',
  'atp_2025_ledger_bridge_v1']){
   assert.ok(backup.includes(required), 'missing '+required);
 }
});
