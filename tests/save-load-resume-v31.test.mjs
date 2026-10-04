import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const app=read('court-boss/app.js');
const edge=read('supabase/functions/court-boss/index.ts');
const daily=read('supabase/migrations/20261004122433_idempotent_daily_clock_training_v25.sql')+'\n'+read('supabase/migrations/20261004175500_audit_reliability_v31.sql');
const recoveryGuards=read('supabase/migrations/20261004010204_live_match_idempotent_commit_guards_v23.sql')+'\n'+read('supabase/migrations/20261004130000_post_match_recovery_v24.sql');
const careerIntegrity=read('supabase/migrations/20261004172500_career_integrity_save_v8_v32.sql');

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


test('match effects and recovery debt are exactly-once per live session',()=>{
  assert.match(recoveryGuards,/primary key\(session_id,effect\)/);
  assert.match(recoveryGuards,/perform 1 from public\.live_match_sessions where id=p_session_id for update/);
  assert.match(recoveryGuards,/where session_id=p_session_id and effect=p_effect/);
  assert.match(recoveryGuards,/'already_applied',true/);
  assert.match(recoveryGuards,/insert into public\.live_match_effect_commits_v23\(session_id,effect,payload\)/);
});


test('save v8 refuses incomplete timeline snapshots before restore mutations',()=>{
  assert.match(edge,/Timeline snapshot failed/);
  assert.match(edge,/Incomplete V8 timeline snapshot/);
  assert.match(edge,/requiredTimelineArrays/);
  assert.match(edge,/managed_timeline_v8/);
});


test('access check validates without acquiring or leaking the write lock',()=>{
  assert.match(edge,/const isAccessCheck=path\.endsWith\("\/api\/access-check"\)/);
  assert.match(edge,/const protectedWrite=[^\n]*!isAccessCheck/);
  assert.match(edge,/if\(protectedWrite\)\{[\s\S]*cb_acquire_write_lock_v31/);
  const authStart=edge.indexOf('const isAccessCheck=');
  const route=edge.indexOf('if(path.endsWith("/api/access-check")',authStart);
  const acquire=edge.indexOf('cb_acquire_write_lock_v31',authStart);
  assert.ok(route>authStart&&acquire>authStart);
  assert.match(edge,/writeLockHeartbeat=setInterval/);
  assert.match(edge,/clearInterval\(writeLockHeartbeat\)/);
});

test('passive bootstrap and career hub stay read-only',()=>{
  const bootStart=edge.indexOf('if(path.endsWith("/api/bootstrap")');
  const bootEnd=edge.indexOf('if(path.endsWith("/api/rankings")',bootStart);
  const boot=edge.slice(bootStart,bootEnd);
  assert.doesNotMatch(boot,/ensureCareerBaselineTemplate\(/);
  assert.doesNotMatch(boot,/career_sync_actionable_inbox/);
  assert.doesNotMatch(boot,/career_sync_operational_alerts/);

  const hubStart=edge.indexOf('if(path.endsWith("/api/career-hub")');
  const hubEnd=edge.indexOf('if(path.endsWith("/api/managed-player-context")',hubStart);
  const hub=edge.slice(hubStart,hubEnd);
  assert.doesNotMatch(hub,/ensure_player_season_plan/);
});


test('career integrity audit understands v8 save scopes and timeline shape',()=>{
  assert.match(careerIntegrity,/CB-CAREER-INTEGRITY-v4/);
  assert.match(careerIntegrity,/managed_timeline_v8/);
  assert.match(careerIntegrity,/managed_timeline_live_v8/);
  assert.match(careerIntegrity,/CB-MANAGED-SAVE-v8/);
  assert.match(careerIntegrity,/court_boss_hof_profiles/);
  assert.match(careerIntegrity,/v_legacy_slots=0/);
});


test('failed load rollback preserves current live session and point ledger',()=>{
  assert.match(edge,/async function captureLiveCheckpointSnapshot/);
  assert.match(edge,/\["active","finished","completed","committed"\]/);
  assert.match(edge,/live_match_events/);
  assert.match(edge,/live_match_point_events/);
  const loadStart=edge.indexOf('if(path.endsWith("/api/load-slot")');
  const loadEnd=edge.indexOf('if(path.endsWith("/api/delete-slot")',loadStart);
  const load=edge.slice(loadStart,loadEnd);
  assert.match(load,/const safetySnapshot=await captureLiveCheckpointSnapshot\(await captureManagedSaveSnapshot\(\)\)/);
  assert.match(load,/await restoreManagedSaveSnapshot\(safetySnapshot\)/);
});
