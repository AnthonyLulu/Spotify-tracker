import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/probe-real-unified-world-week-v71.sql',import.meta.url),'utf8');
test('real QA invokes every game circuit in one actual unified window, not just weekly recovery',()=>{
 assert.match(sql,/public\.run_unified_circuit_window\(p_from,p_to\)/);
 assert.match(sql,/'atp_world',circuit->'world_tournaments'/);
 assert.match(sql,/'world_qualifying',circuit->'world_qualifying'/);
 assert.match(sql,/'junior_world',circuit->'junior_world'/);
 assert.match(sql,/'world_doubles',circuit->'world_doubles'/);
});
test('world matches must have winners, scores and no identity contradictions',()=>{
 assert.match(sql,/AND won>0 AND scored=won/);
 assert.match(sql,/winner_id NOT IN \(player_a_id,player_b_id\)/);
 assert.match(sql,/loser_id NOT IN \(player_a_id,player_b_id\)/);
 assert.match(sql,/winner_id=loser_id/);
 assert.match(sql,/world_matches_evidence_ready/);
});
test('real-game SQL QA is stage-only, locked and rollback-only',()=>{
 assert.match(sql,/STAGING ONLY/);
 assert.match(sql,/FROM public\.game_saves/);
 assert.match(sql,/pg_try_advisory_xact_lock\(2200261201\)/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94832030\)/);
 assert.match(sql,/RAISE EXCEPTION 'CB_UNIFIED_WORLD_QA_FORCE_ROLLBACK'/);
 assert.match(sql,/IF err='CB_UNIFIED_WORLD_QA_FORCE_ROLLBACK' THEN RETURN outcome/);
 assert.match(sql,/REVOKE ALL ON FUNCTION .*\(date,date\)/);
});
