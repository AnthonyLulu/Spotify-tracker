import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const probe=fs.readFileSync(new URL('../qa/world-2050/stage-jan-2026-multiday-rollback-v58.sql',import.meta.url),'utf8');
const cache=fs.readFileSync(new URL('../qa/world-2050/stage-name-pool-cache-experiment-v58.sql',import.meta.url),'utf8');
const original=fs.readFileSync(new URL('../qa/world-2050/stage-name-pool-original-definitions-v58.sql',import.meta.url),'utf8');

test('longer stage QA does not skip weekly boundaries, replays or dates',()=>{
 assert.match(probe,/public\.rollover_season_daily_v22\(2026\)/);
 assert.match(probe,/public\.advance_career_day_v26\('\{\}'::jsonb,'normal',d\)/);
 assert.match(probe,/BETWEEN date '2025-12-31' AND date '2026-01-03'/);
 assert.match(probe,/IF n<>4 THEN RAISE EXCEPTION/);
 assert.match(probe,/weekly_checkpoint_required/);
 assert.match(probe,/weekly_not_faked/);
 assert.doesNotMatch(probe,/mark_weekly_checkpoint_v22/);
});
test('newgen pool arrays are cached per transaction, with legacy fallback and 2025 fixture unchanged',()=>{
 assert.match(cache,/CREATE TEMP TABLE cb_name_pool_cache_v1/);
 assert.match(cache,/ON COMMIT DROP/);
 assert.match(cache,/cb_prime_newgen_name_pools_v1/);
 assert.match(cache,/pg_temp\.cb_name_pool_cache_v1/);
 assert.match(cache,/Backwards-compatible on cache miss/);
 assert.match(cache,/IF firsts is null or lasts is null/);
 assert.match(cache,/public\.generate_newgens/);
 assert.match(original,/public\.cb_generated_player_name/);
 assert.match(original,/public\.generate_newgens/);
 assert.doesNotMatch(cache,/UPDATE\s+public\.players\s+SET\s+game_world_rank/i);
});
test('all durable stage state changes are explicitly rolled back, no completed 2050 claim',()=>{
 assert.match(probe,/CB_REAL_MULTIDAY_ROLLBACK/);
 assert.match(probe,/world_integrity_guard_v18/);
 assert.match(probe,/public\.game_saves/);
 assert.match(probe,/REVOKE ALL ON FUNCTION/);
 const note=fs.readFileSync(new URL('../qa/world-2050/real-jan-v58-and-2050-gate-audit.md',import.meta.url),'utf8');
 assert.match(note,/Full result `ok: false`/);
 assert.match(note,/not.*25 years of actual daily career history/i);
});
