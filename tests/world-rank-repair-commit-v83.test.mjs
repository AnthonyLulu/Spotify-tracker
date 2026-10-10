import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-rank-repair-commit-v83.sql',import.meta.url),'utf8');

test('cannot run while any other week or any save is in progress',()=>{
 assert.match(sql,/world_week_jobs_v1 WHERE status='running'/);
 assert.match(sql,/EXISTS \(SELECT 1 FROM public\.game_saves\)/);
 assert.match(sql,/EXISTS \(SELECT 1 FROM public\.game_save_slots\)/);
 assert.match(sql,/EXISTS \(SELECT 1 FROM public\.career_state\)/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94832021\)/);
});
test('preserve ATP ranking and fail entire transaction if any integrity check fails',()=>{
 assert.match(sql,/before_official_hash IS DISTINCT FROM after_official_hash/);
 assert.match(sql,/after_dupes<>0/);
 assert.match(sql,/official_misranked<>0/);
 assert.match(sql,/retired_ranked<>0/);
 assert.match(sql,/public\.living_world_integrity_audit_v16/);
 assert.match(sql,/RAISE EXCEPTION 'staging world-rank repair failed invariant/);
});
test('rank repair rerun is idempotent and stage-only',()=>{
 assert.match(sql,/first_receipt:=public\.refresh_game_world_ranks\(\)/);
 assert.match(sql,/retry_receipt:=public\.refresh_game_world_ranks\(\)/);
 assert.match(sql,/retry_receipt->>'collision_repaired'/);
 assert.match(sql,/'scope','isolated_staging'/);
 assert.match(sql,/REVOKE ALL ON FUNCTION .*\(\)/);
});
