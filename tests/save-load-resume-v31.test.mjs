import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const app=read('court-boss/app.js');
const edge=read('supabase/functions/court-boss/index.ts');
const daily=read('supabase/migrations/20261004122433_idempotent_daily_clock_training_v25.sql')+'\n'+read('supabase/migrations/20261004175500_audit_reliability_v31.sql');

test('passive local persistence never opens the private access gate',()=>{
  const start=app.indexOf('function persist()');
  const end=app.indexOf('async function loadSaveSlots()',start);
  const block=app.slice(start,end);
  assert.match(block,/authPrompt:false/);
  assert.doesNotMatch(block,/requestCourtBossAccess\(/);
});

test('live match always arms a pre-match autosave checkpoint',()=>{
  assert.match(app,/ensureLivePreMatchCheckpoint/);
  assert.match(app,/saveCareerSlot\(0,'autosave',true,\{preMatchCheckpoint:true\}\)/);
  assert.match(app,/cbLiveRollbackCheckpointV1/);
});

test('startup rollback happens before bootstrap hydration',()=>{
  const init=app.slice(app.indexOf('async function init()'),app.indexOf('async function nav',app.indexOf('async function init()')));
  const rollback=init.indexOf('rollbackUnsavedLiveBatchOnStartup()');
  const bootstrap=init.indexOf("get('/api/bootstrap')");
  assert.ok(rollback>=0&&bootstrap>rollback,'rollback must precede bootstrap');
  assert.match(app,/clearLiveMatchView\(\)/);
  assert.match(app,/liveMatchSessionsByPlayer\.clear\(\)/);
  assert.match(app,/localStorage\.setItem\('cbLocal'/);
});

test('manual slot load rebuilds local state and live session map',()=>{
  const start=app.indexOf('async function loadCareerSlot');
  const end=app.indexOf('async function deleteCareerSlot',start);
  const block=app.slice(start,end);
  assert.match(block,/cleanCareerLocalState\(d\.local_payload\|\|\{\}\)/);
  assert.match(block,/restoredLive/);
  assert.match(block,/liveMatchSessionsByPlayer\.set/);
  assert.match(block,/invalidateCareerCaches\(\)/);
  assert.match(block,/route=local\.liveMatch\?'match':'home'/);
});

test('server slot load has a safety snapshot and restores it on failure',()=>{
  const start=edge.indexOf('if(path.endsWith("/api/load-slot")');
  const end=edge.indexOf('if(path.endsWith("/api/delete-slot")',start);
  const block=edge.slice(start,end);
  assert.match(block,/const safetySnapshot=await captureManagedSaveSnapshot\(\)/);
  assert.match(block,/await restoreManagedSaveSnapshot\(safetySnapshot\)/);
  assert.match(block,/rollback_recovered/);
});

test('save v8 includes career records and Hall of Fame timeline',()=>{
  assert.match(edge,/CB-MANAGED-SAVE-v8/);
  for(const table of [
    'record_occurrences','court_boss_match_stat_lines','court_boss_player_awards',
    'court_boss_world_story_log','court_boss_hof_profiles','court_boss_hof_ballots',
    'court_boss_hof_classes','court_boss_retirement_ceremonies'
  ]) assert.match(edge,new RegExp(table));
});

test('daily advance is idempotent across reload or retry',()=>{
  assert.match(daily,/p_expected_from_date/);
  assert.match(daily,/daily_tick_commit_v25/);
  assert.match(daily,/already_applied/);
  assert.match(daily,/stale_day_request/);
});
