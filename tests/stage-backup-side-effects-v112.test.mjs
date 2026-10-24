import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const backup=readFileSync(new URL('../scripts/cb-stage-independent-backup-verify.sh',import.meta.url),'utf8');
const audit=readFileSync(new URL('../qa/world-2050/stage-side-effect-footprint-v112.sql',import.meta.url),'utf8');
const mustCover=['court_boss_match_stat_lines','player_titles','ranking_history','world_tournament_simulations',
'world_tournament_qualifying_entries','world_qualifying_acceptance_entries','player_training_load_profiles',
'injuries','record_occurrences','court_boss_world_story_log','news_items','finance_transactions',
'player_tournament_history','world_qualifying_states'];
test('off-database proof includes world side-effect tables, split into 12/7/7 for bounded execution',()=>{
 for(const name of mustCover) assert.ok(backup.includes('public.'+name),'Missing backup for '+name);
 assert.equal((backup.match(/ AS check_key,/g)||[]).length,26);
 assert.equal((backup.match(/fingerprint_sql_\d="\$\(cat/g)||[]).length,3);
 assert.match(backup,/local dest="\$1"/);
 assert.match(backup,/Object\.keys\(all\)\.length!==26/);
 assert.match(backup,/f1="\$\(psql/);
 assert.match(backup,/f3="\$\(psql/);
 assert.match(backup,/stage_or_restored_fingerprints "\$CB_E2E_RESTORE_TEST_DB_URL"/);
 assert.match(backup,/Stage changed during multi-session export/);
 assert.match(backup,/RESTORED_DIGESTS\.json/);
});
test('observational SQL never asserts that all injuries were caused by invalid events',()=>{
 assert.match(audit,/BEGIN READ ONLY;/);
 assert.match(audit,/world_tournament_simulations/);
 assert.match(audit,/distinct_players_touched_by_invalid_matches/);
 assert.match(audit,/participants_with_any_injury_history/);
 assert.match(audit,/'injuries_causally_attributed_to_invalid_matches',false/);
 assert.match(audit,/'world_state_may_be_repaired_by_selective_deletion',false/);
 assert.match(audit,/'world_2050_certified',false/);
 assert.doesNotMatch(audit,/\b(?:INSERT INTO|UPDATE public|DELETE FROM|TRUNCATE TABLE|DROP TABLE)\b/i);
});
