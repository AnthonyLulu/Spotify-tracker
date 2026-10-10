import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/probe-real-90-day-dec25-mar26-v68.sql',import.meta.url),'utf8');

test('90 actual daily steps and 12 weekly checkpoints use the production-derived RPCs',()=>{
 assert.match(sql,/last_date date:='2026-03-01'/);
 assert.match(sql,/d date:='2025-12-01'/);
 assert.match(sql,/n_days>90/);
 assert.match(sql,/n_commits<>90 OR n_other<>1 OR n_checkpoints<>12/);
 assert.match(sql,/public\.advance_career_day_v26\('\{\}'::jsonb,'normal',d\)/);
 assert.match(sql,/public\.simulate_world_week\(/);
 assert.match(sql,/public\.mark_weekly_checkpoint_v22\(d\)/);
 assert.match(sql,/public\.rollover_season_daily_v22\(2026\)/);
 assert.match(sql,/public\.world_integrity_guard_v18\(date '2026-03-01'\)/);
});

test('week numbering advances throughout 2026, never staying week 1 after Jan',()=>{
 assert.match(sql,/ELSE \(\(d-date '2026-01-01'\)\/7\)\+1/);
 assert.match(sql,/e\.value->>'on'='2026-02-22'/);
 assert.match(sql,/e\.value->>'world_week'\)::int=8/);
 assert.match(sql,/jsonb_array_length\(v_week_numbers\)<>12/);
});

test('isolated rollback and fail-closed guards prevent any persistent fixture changes',()=>{
 assert.match(sql,/ISOLATED SUPABASE STAGE ONLY/);
 assert.match(sql,/FROM public\.game_saves/);
 assert.match(sql,/pg_try_advisory_xact_lock\(2200261201\)/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(sql,/RAISE EXCEPTION 'CB_E2E_TEN_DAY_FORCE_ROLLBACK'/);
 assert.match(sql,/EXCEPTION WHEN OTHERS THEN/);
 assert.match(sql,/RETURN outcome/);
 assert.match(sql,/REVOKE ALL ON FUNCTION .* FROM PUBLIC,anon,authenticated/);
});

test('real end date and retry are represented and cannot falsely pass 62 days',()=>{
 assert.match(sql,/date '2026-02-28'/);
 assert.match(sql,/n_days>90/);
 assert.doesNotMatch(sql,/n_commits<>62 OR n_other<>1 OR n_checkpoints<>8/);
 assert.match(sql,/coalesce\(\(retry->>'already_applied'\)::boolean,false\) IS DISTINCT FROM true/);
});
