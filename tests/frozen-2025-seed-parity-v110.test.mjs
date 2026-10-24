import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/frozen-2025-seed-parity-v110.sql',import.meta.url),'utf8');
test('2025 seed parity audit uses a read-only transaction and refuses 2050 certification',()=>{
 assert.match(sql,/BEGIN READ ONLY;/);
 assert.match(sql,/SET LOCAL statement_timeout/);
 assert.match(sql,/synthetic_adult_seed_v1/);
 assert.match(sql,/synthetic_adult_attributes_v1/);
 assert.match(sql,/world_rank_seed_plan_v1/);
 assert.match(sql,/atp_20251201_reference_v1/);
 assert.match(sql,/atp_2025_ledger_bridge_v1/);
 assert.match(sql,/p\.id=1000000\+s\.slot/);
 assert.match(sql,/to_jsonb\(a\) @> \(to_jsonb\(sa\)-'slot'\)/);
 assert.match(sql,/'2050_certified',false/);
 assert.match(sql,/'can_delete_live_2026_world',false/);
 assert.match(sql,/COMMIT;/);
 assert.doesNotMatch(sql,/\b(?:UPDATE|DELETE|TRUNCATE|DROP|ALTER|CREATE|INSERT)\s+(?:INTO\s+|FROM\s+|TABLE\s+)?(?:public|cb_e2e_reconstruction_20261010)\./i);
});
