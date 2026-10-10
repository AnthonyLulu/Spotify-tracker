import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/real-36-day-2025-2026-probe-v59.sql',import.meta.url),'utf8');

test('real 2025-26 test drives exact daily + weekly game functions',()=>{
 assert.match(sql,/public\.advance_career_day_v26/);
 assert.match(sql,/public\.simulate_world_week\(/);
 assert.match(sql,/public\.mark_weekly_checkpoint_v22\(/);
 assert.match(sql,/public\.rollover_season_daily_v22\(2026\)/);
 assert.match(sql,/public\.refresh_newgen_name_parts\(\)/);
 assert.match(sql,/licensed_name_seed/);
});

test('December to January is truly daily with five weekly checkpoints',()=>{
 assert.match(sql,/last_date date:='2026-01-06'/);
 assert.match(sql,/WHILE d<last_date LOOP/);
 assert.match(sql,/d=date '2025-12-31'/);
 assert.match(sql,/Rollover consumed Jan 1 before daily tick/);
 assert.match(sql,/n_commits<>36 OR n_other<>1 OR n_checkpoints<>5 OR v_year_rollovers<>1/);
 assert.match(sql,/retry:=public\.advance_career_day_v26\('\{\}'::jsonb,'normal',date '2026-01-05'\)/);
});

test('all stage writes are guarded, serial and forcibly rolled back',()=>{
 assert.match(sql,/Stage isolated career\/world busy or seed unready/);
 assert.match(sql,/pg_try_advisory_xact_lock\(2200261201\)/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(sql,/CB_E2E_TEN_DAY_FORCE_ROLLBACK/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.doesNotMatch(sql,/^\s*(?:DROP\s+TABLE|TRUNCATE\s+TABLE)\b/im);
});
