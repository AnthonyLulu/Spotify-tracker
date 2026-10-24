import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/isolated-multicircuit-coverage-v100.sql',import.meta.url),'utf8');
test('unified world audit uses last completed week, not an active partial week',()=>{
 assert.match(sql,/max\(to_date\) AS through_date/);
 assert.match(sql,/status='completed' AND completed_items=expected_items/);
 assert.match(sql,/mens_doubles_planned/);
 assert.match(sql,/mens_doubles_persisted/);
 assert.match(sql,/davis_scored_rubbers/);
 assert.match(sql,/junior_doubles_scored_matches/);
 assert.match(sql,/ncaa_individual_simulations_in_calendar/);
});
test('read-only stage gate cannot certify untested circuits or 2050',()=>{
 assert.match(sql,/BEGIN READ ONLY/);
 assert.match(sql,/'cross_circuit_2050_certified',false/);
 assert.match(sql,/'real_mobile_save_load_2050_certified',false/);
 assert.doesNotMatch(sql,/\b(?:insert|update|delete|alter|truncate)\s+(?:into\s+)?public\./i);
});
