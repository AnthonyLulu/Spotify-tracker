import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-rank-collision-repair-rollback-v81.sql',import.meta.url),'utf8');
test('repair refuses any active world batch or game saves, never waiting for live lock',()=>{
 assert.match(sql,/world_week_jobs_v1 j/);
 assert.match(sql,/j\.status='running'/);
 assert.match(sql,/public\.game_saves/);
 assert.match(sql,/public\.game_save_slots/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(sql,/pg_try_advisory_xact_lock\(94830000\)/);
});
test('repair must prove zero duplicates without changing official frozen ranks',()=>{
 assert.match(sql,/public\.refresh_game_world_ranks\(\)/);
 assert.match(sql,/after_duplicates=0/);
 assert.match(sql,/after_second_duplicates=0/);
 assert.match(sql,/official_rank_hash_before=official_rank_hash_after/);
 assert.match(sql,/unranked_after=0/);
 assert.match(sql,/retired_ranked_after=0/);
});
test('second rank repair must be idempotent and every write rolls back',()=>{
 assert.match(sql,/second_run:=public\.refresh_game_world_ranks\(\)/);
 assert.match(sql,/second_run->>'collision_repaired'/);
 assert.match(sql,/CB_RANK_REPAIR_V81_FORCED_ROLLBACK/);
 assert.match(sql,/IF err='CB_RANK_REPAIR_V81_FORCED_ROLLBACK' THEN RETURN report/);
 assert.match(sql,/REVOKE ALL ON FUNCTION .*\(\)/);
});
