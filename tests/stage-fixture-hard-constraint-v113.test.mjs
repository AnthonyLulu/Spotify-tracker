import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const migration=readFileSync(new URL('../qa/world-2050/stage-fixture-hard-constraint-v113.sql',import.meta.url),'utf8');
const audit=readFileSync(new URL('../qa/world-2050/stage-fixture-hard-constraint-audit-v113.sql',import.meta.url),'utf8');
test('SQL check is stage-only and fail closed for active or null-active cancelled fixtures',()=>{
 assert.match(migration,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(migration,/cb_e2e_reconstruction_20261010\.world_week_jobs_v1/);
 for(const x of ['game_saves','game_save_slots','career_state','SET LOCAL lock_timeout','SET LOCAL statement_timeout','VALIDATE CONSTRAINT'])assert.ok(migration.includes(x),x);
 assert.match(migration,/ADD CONSTRAINT cb_stage_no_play_cancelled_postponed_v113/);
 assert.match(migration,/coalesce\(is_active,true\)/);
 assert.match(migration,/cancelled\|canceled\|postponed\|abandoned\|annul\[ée\]/);
 assert.doesNotMatch(migration,/\b(?:DELETE FROM|TRUNCATE|DROP TABLE|UPDATE public\.|INSERT INTO public\.)\b/i);
 assert.match(migration,/COMMIT;/);
});
test('auditor never certifies poisoned world or claims cleanup',()=>{
 assert.match(audit,/BEGIN READ ONLY;/);
 assert.match(audit,/c\.convalidated/);
 assert.match(audit,/bad_active_or_null_rows/);
 assert.match(audit,/'guard_does_not_repair_historical_results',true/);
 assert.match(audit,/'2050_certified',false/);
});
