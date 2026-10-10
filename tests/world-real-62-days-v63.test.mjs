import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const src=fs.readFileSync(new URL('../qa/world-2050/probe-real-62-day-dec25-feb26-v63.sql',import.meta.url),'utf8');

test('live world 62 day probe never substitutes a stub adapter',()=>{
 assert.match(src,/public\.advance_career_day_v26/);
 assert.match(src,/public\.simulate_world_week/);
 assert.match(src,/public\.mark_weekly_checkpoint_v22/);
 assert.match(src,/public\.rollover_season_daily_v22\(2026\)/);
 assert.match(src,/last_date date:='2026-02-01'/);
 assert.match(src,/n_commits<>62 OR n_other<>1 OR n_checkpoints<>8 OR v_year_rollovers<>1/);
});
test('weekly 2026 simulation reuses year-reset week number and licensed names',()=>{
 assert.match(src,/d<date '2026-01-01'/);
 assert.match(src,/FROM cb_e2e_reconstruction_20261010\.licensed_name_seed/);
 assert.match(src,/public\.refresh_newgen_name_parts\(\)/);
 assert.match(src,/Rollover consumed Jan 1 before daily tick/);
 assert.match(src,/2026-01-31/);
});
test('stage career replay uses deliberate full rollback and session lock',()=>{
 assert.match(src,/pg_try_advisory_xact_lock\(2200261201\)/);
 assert.match(src,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(src,/CB_E2E_TEN_DAY_FORCE_ROLLBACK/);
 assert.match(src,/select count\(\*\) from public\.game_saves/i);
 assert.match(src,/REVOKE ALL ON FUNCTION/);
});
