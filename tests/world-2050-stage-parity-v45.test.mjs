import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const status=JSON.parse(fs.readFileSync(new URL('../qa/world-2050/reconstruction-status-2026-10-10.json',import.meta.url),'utf8'));
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-parity-gate.sql',import.meta.url),'utf8');

test('reconstruction status never claims certification with missing core objects',()=>{
 const s=status.stage_parity;
 const incomplete=s.functions.missing||s.functions.definition_drift||s.constraints.missing||
  s.constraints.definition_drift||s.indexes.missing||s.views.missing||
  s.triggers.missing||s.edge_functions.deployed===0||
  !status.fixture_world_guard.passed||!status.checkpoint.external_backup_verified;
 assert.ok(incomplete);
 assert.equal(status.published_career_2050_certified,false);
});

test('a real world seed must clear official active-adult floor',()=>{
 const w=status.fixture_world_guard;
 assert.ok(w.active_adults<w.required_active_adults);
 assert.equal(w.passed,false);
 assert.ok(w.near_calendar_duplicate_groups>0);
});

test('all original fixture tables have a confirmed independent row digest checkpoint',()=>{
 assert.equal(status.checkpoint.tables,85);
 assert.equal(status.checkpoint.verified_original_data_tables,85);
 assert.equal(status.checkpoint.kind,'in-project-only');
 assert.equal(status.checkpoint.external_backup_verified,false);
});

test('live preflight reads catalog metadata and detects function/constraint definition drift',()=>{
 assert.match(sql,/pg_get_functiondef/);
 assert.match(sql,/pg_get_constraintdef/);
 assert.match(sql,/verify_original_fixture_columns/);
 assert.match(sql,/unrestored_triggers/);
 assert.match(sql,/is_2050_certified',false/);
 assert.doesNotMatch(sql,/\b(?:DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|UPDATE\s+public\.|INSERT\s+INTO\s+public\.)/i);
});
