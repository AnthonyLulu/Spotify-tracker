import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const s=fs.readFileSync(new URL('../qa/world-2050/stage-weekly-rank-repair-v84.sql',import.meta.url),'utf8');

test('the weekly staging job preserves actual single-event checks',()=>{
 assert.match(s,/simulate_world_event_batch_fast_v2/);
 assert.match(s,/world_tournament_matches/);
 assert.match(s,/world_ranking_points/);
 assert.match(s,/world_tournament_simulations/);
});
test('repair occurs AFTER ATP points but BEFORE checkpoint marked completed',()=>{
 const x=s.indexOf('perform public.refresh_world_rankings(j.to_date);');
 const y=s.indexOf('rank_repair:=public.refresh_game_world_ranks();');
 const z=s.indexOf("set status='completed',updated_at=now()");
 assert.ok(x>=0&&y>x&&z>y);
 assert.match(s,/pg_try_advisory_xact_lock\(94830000\)/);
});
test('full nested rank integrity and official ranks are hard requirements',()=>{
 assert.match(s,/living_world_integrity_audit_v16/);
 assert.match(s,/duplicate_active_world_ranks/);
 assert.match(s,/game_world_rank IS DISTINCT FROM p\.ranking/);
 assert.match(s,/RAISE EXCEPTION 'world-week rank integrity red after recovery/);
});
test('stage-only helper locks world fixture and does not grant public execute',()=>{
 assert.match(s,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(s,/REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010\.step_world_week_v2\(text\)/);
});
