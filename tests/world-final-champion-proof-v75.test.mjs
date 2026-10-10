import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-verified-world-final-v75.sql',import.meta.url),'utf8');
test('world QA uses the real draw engine, not a weekly stats-only stub',()=>{
 assert.match(sql,/public\.simulate_world_qualifying_full\(p_id/);
 assert.match(sql,/public\.simulate_world_knockout_tournament_full\(p_id/);
 assert.match(sql,/world_tournament_matches/);
 assert.match(sql,/world_tournament_simulations/);
});
test('champion must be written and match the final winner',()=>{
 assert.match(sql,/v_stored_champion IS NOT NULL/);
 assert.match(sql,/v_stored_champion=v_final_winner/);
 assert.match(sql,/r->>'champion_id'/);
 assert.match(sql,/'champion_id',v_stored_champion/);
 assert.doesNotMatch(sql,/'winner_id',r->'winner_id'/);
});
test('completed bracket only passes with all scored matches and valid identities',()=>{
 assert.match(sql,/v_total=v_scored AND v_invalid=0/);
 assert.match(sql,/v_final_matches=1/);
 assert.match(sql,/winner_id<>loser_id/);
 assert.match(sql,/winner_id in \(player_a_id,player_b_id\)/);
 assert.match(sql,/coalesce\(length\(trim\(score\)\),0\)>0/);
});
test('QA remains stage-only, date-bound and rolls every game mutation back',()=>{
 assert.match(sql,/p_id not in \(65,199,906\)/);
 assert.match(sql,/world_tournament_simulations\)<>0/);
 assert.match(sql,/raise exception 'EXPECTED_DRAW_TEST_ROLLBACK'/i);
 assert.match(sql,/if failure='EXPECTED_DRAW_TEST_ROLLBACK' then return out/i);
 assert.match(sql,/REVOKE ALL ON FUNCTION .* FROM PUBLIC,anon,authenticated/);
});
