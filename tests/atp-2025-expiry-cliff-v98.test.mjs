import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/atp-2025-expiry-cliff-v98.sql',import.meta.url),'utf8');
test('2025 cliff gate does not silently estimate tournament dates or points',()=>{
 assert.match(sql,/BEGIN READ ONLY/);
 assert.match(sql,/is_estimated=true/);
 assert.match(sql,/rank_category='Reconciliation'/);
 assert.match(sql,/drop_date=DATE '2026-11-30'/);
 assert.match(sql,/synthetic_cliff_rows=0 AND e.estimated_2025_rows=0/);
 assert.match(sql,/'may_certify_2025_to_2050_world',false/);
});
test('2025 gate exposes exact provenance totals, no writes',()=>{
 assert.match(sql,/'sourced_2025_per_event_rows'/);
 assert.match(sql,/'unjustified_cliff_points'/);
 assert.match(sql,/'expected_reference_rows',200/);
 assert.doesNotMatch(sql,/\b(?:insert|update|delete|alter|truncate)\s+(?:into\s+)?public\./i);
});
