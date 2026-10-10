import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-jan-2026-multiday-rollback-v58.sql',import.meta.url),'utf8');
test('stage-only real engine: 4 actual successive days with one idempotent retry each',()=>{
 assert.match(sql,/public\.rollover_season_daily_v22\(2026\)/);
 assert.match(sql,/public\.advance_career_day_v26\('\{\}'::jsonb,'normal',d\)/);
 assert.match(sql,/FOR d IN SELECT pg_catalog\.generate_series\(date '2025-12-31',date '2026-01-03'/);
 assert.match(sql,/already_applied/);
 assert.match(sql,/IF n<>4 THEN RAISE EXCEPTION/);
 assert.match(sql,/jsonb_array_length\(coalesce\(x->'training'/);
});
test('weekly simulation is NOT bypassed just to inflate career durability claims',()=>{
 assert.match(sql,/weekly_checkpoint_required/);
 assert.match(sql,/public\.world_integrity_guard_v18\(date '2026-01-04'\)/);
 assert.match(sql,/weekly_not_faked/);
 assert.doesNotMatch(sql,/public\.mark_weekly_checkpoint_v22/);
});
test('mutations are rollback-only, and no production script is produced',()=>{
 assert.match(sql,/Stage is not exclusively available/);
 assert.match(sql,/CB_REAL_MULTIDAY_ROLLBACK/);
 assert.match(sql,/rolled_back/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/public\.game_saves/);
});
