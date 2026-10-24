import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const v96=readFileSync(new URL('../qa/world-2050/stage-calendar-semantic-gate-v96.sql',import.meta.url),'utf8');
const v97=readFileSync(new URL('../qa/world-2050/stage-week-scheduler-calendar-block-v97.sql',import.meta.url),'utf8');
test('stage verifier explicitly refuses cancelled/postponed tournament receipts',()=>{
 assert.match(v96,/verify_persisted_singles_week_v96/);
 assert.match(v96,/cancelled\|canceled\|postponed/);
 assert.match(v96,/calendar_semantics_ok',false/);
 assert.match(v96,/invalid_calendar_events/);
 assert.match(v96,/certifies_full_unified_week',false/);
 assert.match(v96,/verify_persisted_singles_week_v80/);
});
test('future stage week selection excludes cancelled / postponed tournament titles',()=>{
 assert.match(v97,/begin_world_week_v2/);
 assert.match(v97,/t\.name !~\*/);
 assert.match(v97,/cancelled\|canceled\|postponed/);
 assert.match(v97,/previous_week_calendar_invalid/);
 assert.match(v97,/step_world_week_v2/);
 assert.match(v97,/invalid_calendar_events/);
 assert.match(v97,/cb_e2e_checkpoint_20261010\.players/);
});
test('staging QA scripts never delete existing simulated results',()=>{
 for(const src of [v96,v97]){
  assert.doesNotMatch(src,/\b(?:DELETE|TRUNCATE|DROP|UPDATE)\s+(?:FROM\s+)?public\./i);
  assert.doesNotMatch(src,/\bINSERT\s+INTO\s+public\./i);
 }
});
