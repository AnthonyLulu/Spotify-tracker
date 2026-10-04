import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');

const recovery=read('supabase/migrations/20261004130000_post_match_recovery_v24.sql');
const recoveryClock=read('supabase/migrations/20261004131500_daily_recovery_clock_v24.sql');
const training=read('supabase/migrations/20261004134000_recovery_aware_training_v25.sql');
const recoveryFix=read('supabase/migrations/20261004134500_recovery_injury_state_cleanup_v25.sql');
const backend=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');

test('live match load uses duration, effort and weather then seeds recovery exactly once',()=>{
  assert.match(backend,/const durationMinutes=Math\.max\(40,Math\.min\(330,/);
  assert.match(backend,/const fatigueAdd=Math\.max\(5,Math\.min\(19,/);
  assert.match(backend,/heat_load:Number\(heatLoad\.toFixed\(2\)\)/);
  assert.match(backend,/wind_load:Number\(windLoad\.toFixed\(2\)\)/);
  assert.match(backend,/p_effect:"recovery_managed_v24"/);
  assert.match(recovery,/live_match_effect_commits_v23/);
  assert.match(recovery,/already_applied/);
});

test('doubles recovery is player scoped and partner load is slightly reduced',()=>{
  assert.match(backend,/p_effect:"recovery_partner_v24"/);
  assert.match(backend,/p_role_multiplier:\.90/);
  assert.match(backend,/const doublesDurationMinutes=Math\.max\(35,Math\.min\(240,/);
});

test('daily recovery owns passive recovery and travel only once per date',()=>{
  assert.match(recovery,/last_recovery_date is not null and v_load\.last_recovery_date>=v_date/);
  assert.match(recovery,/travel_recovery_debt/);
  assert.match(recovery,/current_country/);
  assert.match(recovery,/staff_medical_rating/);
  assert.match(recovery,/recommended_session/);
  assert.match(recoveryClock,/apply_managed_recovery_day_v24\(v_to,v_player_id\)/);
});

test('training no longer double-counts full-rest recovery',()=>{
  assert.match(training,/when v_session='Récupération' then -\.25/);
  assert.match(training,/else 0\n    end;/);
  assert.doesNotMatch(training,/else -1\.25/);
  assert.match(training,/condition_owner','daily_recovery_plus_training_load/);
});

test('residual match and travel debt reduce adaptation and raise overload risk',()=>{
  assert.match(training,/v_recovery_pressure:=greatest\(0,least\(1,\(v_post_match_debt\+v_travel_debt\)\/30\.0\)\)/);
  assert.match(training,/v_recovery_gain_mult:=greatest\(\.52,1-v_recovery_pressure\*\.42\)/);
  assert.match(training,/\+v_recovery_pressure\*8/);
  assert.match(training,/\*v_recovery_gain_mult;/);
});

test('training niggles become real short medical records',()=>{
  assert.match(training,/insert into public\.injuries/);
  assert.match(training,/'Gêne musculaire','minor',v_date,v_date\+2/);
  assert.match(recoveryFix,/orphan_status_cleared/);
});

test('weekly checkpoint does not recover managed players a second time',()=>{
  assert.match(recovery,/managed_players_restored/);
  assert.match(recovery,/managed_recovery_owner','CB-DAILY-RECOVERY-v24/);
  assert.match(recovery,/condition_owner','CB-DAILY-RECOVERY-v24/);
  assert.match(recovery,/CB-MEDICAL-WEEK-v24-NO-DOUBLE-COUNT/);
});

test('training UI exposes the recovery chain',()=>{
  assert.match(app,/Bilan entraînement & récupération/);
  assert.match(app,/Dette post-match/);
  assert.match(app,/Conseil staff/);
  assert.match(app,/recovery_gain_multiplier/);
});
