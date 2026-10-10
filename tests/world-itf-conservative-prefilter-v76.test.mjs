import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-itf-full-draw-prefilter-v76.sql',import.meta.url),'utf8');
const probe=fs.readFileSync(new URL('../qa/world-2050/stage-itf-verified-draw-probe-v76.sql',import.meta.url),'utf8');
test('stage ITF fast path has a superset of all dated eligible ranks, not an arbitrary top-N',()=>{
 assert.match(sql,/p\.game_world_rank between v_min_rank and v_max_rank/);
 assert.match(sql,/p\.ranking between v_min_rank and v_max_rank/);
 assert.match(sql,/from public\.ranking_history as rh/);
 assert.match(sql,/rh\.snapshot_date<=t\.start_date/);
 assert.match(sql,/rh\.ranking between v_min_rank and v_max_rank/);
 assert.doesNotMatch(sql,/limit 128\b|limit 256\b|limit 420\b/);
});
test('all original rich ITF entrant and match rules are still evaluated',()=>{
 assert.match(sql,/public\.tournament_entry_eligibility\(p\.id,t\.id,'candidate'\)/);
 assert.match(sql,/public\.ai_player_commits_to_tournament\(p\.id,t\.id\)/);
 assert.match(sql,/public\.player_tournament_calendar_conflict\(p\.id,t\.id,'candidate'\)/);
 assert.match(sql,/world_tournament_matches/);
 assert.match(sql,/world_tournament_simulations/);
});
test('copied engine and real-draw QA cannot overwrite the public tournament engine',()=>{
 assert.match(sql,/CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010\.simulate_world_knockout_tournament_full_qa_v76/);
 assert.match(probe,/cb_e2e_reconstruction_20261010\.simulate_world_knockout_tournament_full_qa_v76\(p_id/);
 assert.match(probe,/if p_id<>199/);
 assert.match(probe,/RAISE EXCEPTION 'EXPECTED_DRAW_TEST_ROLLBACK'/i);
 assert.match(probe,/REVOKE ALL ON FUNCTION .* FROM PUBLIC,anon,authenticated/);
});
