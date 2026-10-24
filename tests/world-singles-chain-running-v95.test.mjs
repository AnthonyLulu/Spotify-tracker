import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

// Offline contract checks: these tests never access Supabase or any user save.
const sql=readFileSync(new URL('../qa/world-2050/isolated-singles-chain-fast-v94.sql',import.meta.url),'utf8');

test('the strict receipt checks only a fully persisted historical week',()=>{
 assert.match(sql,/last_finished AS MATERIALIZED/);
 assert.match(sql,/WHERE status='completed' AND completed_items=expected_items/);
 assert.match(sql,/actual_items=expected_items AND actual_done=expected_items/);
 assert.match(sql,/ORDER BY to_date DESC LIMIT 1/);
 assert.match(sql,/FROM last_finished/);
 assert.match(sql,/verify_persisted_singles_week_v80\(job_key\)/);
 assert.doesNotMatch(sql,/SELECT job_key FROM job_state ORDER BY to_date DESC LIMIT 1/);
});
test('the active or busy world week stays visible but cannot be certified',()=>{
 for(const token of ["'weeks_unfinished'","'in_progress'","'committed_items'","'all_started_weeks_completed'","'2050_certified',false","'full_unified_circuits_certified',false"]){
  assert.ok(sql.includes(token),'missing '+token);
 }
 assert.match(sql,/FROM job_state WHERE status<>'completed'/);
 assert.match(sql,/FROM summary s LEFT JOIN strict_receipt r ON true/);
});
test('this staging audit is read-only, bounded and never replays matches',()=>{
 assert.match(sql,/BEGIN READ ONLY;/);
 assert.match(sql,/SET LOCAL statement_timeout='15000ms'/);
 assert.doesNotMatch(sql,/\b(?:insert|update|delete|truncate|alter|drop|call)\s+(?:into\s+)?(?:public|cb_e2e_reconstruction_20261010)\./i);
});
