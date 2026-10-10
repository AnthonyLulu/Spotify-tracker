import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/stage-real-january-probe-v59.sql',import.meta.url),'utf8');
test('rollover checks its ACTUAL new_year response and junior rankings',()=>{
 assert.match(sql, /coalesce\(\(r->>'new_year'\)::integer,0\)<>2026/);
 assert.match(sql, /junior_display_pool/);
 assert.match(sql, /junior_doubles_pool/);
 assert.match(sql, /2025-12-31/);
 assert.doesNotMatch(sql, /coalesce\(\(r->>'ok'\)::boolean,false\) IS DISTINCT FROM true THEN[\s\S]{0,100}Actual yearly rollover failed/);
});
test('probe serializes with 36-day world probe and rolls back everything',()=>{
 assert.match(sql,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(sql,/CB_REAL_MULTIDAY_ROLLBACK/);
 assert.match(sql,/rolled_back/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/from public.career_state/);
 assert.match(sql,/from public.game_saves/);
});
