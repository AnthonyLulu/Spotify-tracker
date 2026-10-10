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

test('isolated 2025 adult world clears guard but is not a 2050 replay certification',()=>{
 const w=status.fixture_world_guard;
 assert.ok(w.active_adults>=w.required_active_adults);
 assert.equal(w.passed,true);
 assert.equal(w.near_calendar_duplicate_groups,0);
 assert.equal(status.published_career_2050_certified,false);
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
 assert.match(sql,/verify_original_fixture_rows_v3/);
 assert.match(sql,/unrestored_triggers/);
 assert.match(sql,/is_2050_certified',false/);
 assert.doesNotMatch(sql,/\b(?:DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|UPDATE\s+public\.|INSERT\s+INTO\s+public\.)/i);
});

const preserved=fs.readFileSync(new URL('../qa/world-2050/verify-original-fixture-rows-v3.sql',import.meta.url),'utf8');
test('the isolated fixture V3 guard detects lost originals despite additive synthetic rows',()=>{
 assert.match(preserved,/EXCEPT ALL/);
 assert.match(preserved,/checkpoint_digest/);
 assert.match(preserved,/content_md5/);
 assert.match(preserved,/SECURITY INVOKER/i);
 assert.match(preserved,/\bchecked<>85\b/);
 assert.match(preserved,/\bmissing_rows<>0\b/);
 assert.doesNotMatch(preserved,/\b(?:DROP\s+TABLE|TRUNCATE\s+TABLE|DELETE\s+FROM|UPDATE\s+public\.|INSERT\s+INTO\s+public\.)/i);
});
test('only audited tournament 132/133 flags can differ from checkpoint',()=>{
 assert.match(preserved,/s\.id IN \(132,133\)/);
 assert.match(preserved,/p\.id IN \(132,133\)/);
 assert.match(preserved,/approved<>2/);
 assert.match(preserved,/calendar_duplicate_adjustments/);
 assert.match(preserved,/j\.old_active IS TRUE AND j\.new_active IS FALSE/);
 assert.match(preserved,/REVOKE ALL ON FUNCTION/);
});

test('real SQL engine trials never imply a finished 2050 simulation',()=>{
 const t=status.test_results;
 assert.equal(t.real_daily_2025_12_01_to_2025_12_10.passed,true);
 assert.equal(t.real_daily_2025_12_01_to_2025_12_10.old_day_retry_idempotent,true);
 assert.equal(t.rollover_2025_to_2026.first_processed_day,'2026-01-01');
 assert.equal(t.atp_250_draws_2026_01_17.matches,62);
 assert.equal(t.challenger75_noumea_2026_01_11.main_matches,31);
 assert.equal(t.fifteen_draws_january_2026.passed,false);
 assert.equal(t.itf_m25_single_draw.passed,false);
 for(const [name,trial] of Object.entries(t)){
  if(name==='itf_m25_single_draw')assert.equal(trial.not_executed,true);
  else assert.equal(trial.rolled_back,true);
 }
 assert.equal(status.published_career_2050_certified,false);
});
test('SQL parity is complete but external snapshot and game Edge are not',()=>{
 const s=status.stage_parity;
 assert.equal(s.tables.missing,0);
 assert.equal(s.columns.missing,0);
 assert.equal(s.constraints.definition_drift,0);
 assert.equal(s.functions.definition_identical,648);
 assert.equal(s.functions.definition_drift,2);
 assert.deepEqual(s.functions.reviewed_stage_only_overrides.map(x=>x.signature).sort(),[
  'cb_generated_player_name(p_country text, p_seed integer)',
  'rollover_season_daily_v22(p_new_year integer)'
 ]);
 assert.equal(s.indexes.missing,0);
 assert.equal(s.triggers.missing,0);
 assert.equal(s.views.missing,0);
 assert.equal(s.edge_functions.deployed,0);
 assert.equal(status.checkpoint.external_backup_verified,false);
});
