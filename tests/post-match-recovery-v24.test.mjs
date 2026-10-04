import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');
const backend=read('supabase/functions/court-boss/index.ts');
const recovery=read('supabase/migrations/20261004130000_post_match_recovery_v24.sql');
const clock=read('supabase/migrations/20261004131500_daily_recovery_clock_v24.sql');
const daily=read('court-boss/daily-career-v22.js');
const trainingOwner=read('supabase/migrations/20261004135000_training_recovery_single_owner_v24.sql');
const play=read('court-boss/play.html');

test('live singles and doubles expose duration-driven physical load',()=>{
  assert.match(backend,/const durationMinutes=Math\.max\(40,Math\.min\(330/);
  assert.match(backend,/const doublesDurationMinutes=Math\.max\(35,Math\.min\(240/);
  assert.match(backend,/durationLoad/);
  assert.match(backend,/doublesDurationLoad/);
  assert.match(backend,/heatLoad/);
  assert.match(backend,/windLoad/);
  assert.match(backend,/effortLoad/);
  assert.match(backend,/match_duration_minutes:durationMinutes/);
  assert.match(backend,/match_duration_minutes:doublesDurationMinutes/);
});

test('each live result seeds idempotent post-match recovery debt',()=>{
  assert.match(recovery,/create or replace function public\.seed_live_match_recovery_v24/);
  assert.match(recovery,/live_match_effect_commits_v23/);
  assert.match(recovery,/post_match_recovery_debt/);
  assert.match(backend,/p_effect:"recovery_managed_v24"/);
  assert.match(backend,/p_effect:"recovery_partner_v24"/);
  assert.match(backend,/p_role_multiplier:\.90/);
});

test('daily recovery runs before training and can medically restrict the session',()=>{
  const recoveryPos=clock.indexOf('apply_managed_recovery_day_v24');
  const trainingPos=clock.indexOf('apply_managed_training_day_v22');
  assert.ok(recoveryPos>=0&&trainingPos>=0&&recoveryPos<trainingPos);
  assert.match(clock,/automatic_medical_restriction/);
  assert.match(clock,/'morning','Récupération'/);
  assert.match(clock,/'afternoon','Repos'/);
  assert.match(clock,/jsonb_build_object\('recovery',v_recovery\)/);
});

test('travel is applied once through the recovery state instead of tournament terminal rewards',()=>{
  assert.match(recovery,/current_country/);
  assert.match(recovery,/travel_recovery_debt/);
  assert.match(recovery,/last_travel_date/);
  assert.match(recovery,/country_region_v24/);
  assert.match(recovery,/v_travel_tolerance/);
  assert.match(recovery,/v_target_country/);
  assert.match(recovery,/Voyage /);
});

test('medical staff, recovery ability and physio affect overnight recovery',()=>{
  for(const marker of [
    'v_recovery_attr','v_natural','v_medical','v_fitness_staff',
    'v_protocol_bonus','v_physio','staff_effectiveness_multiplier'
  ]) assert.ok(recovery.includes(marker),'missing '+marker);
  assert.match(recovery,/recommended_session/);
  assert.match(recovery,/medical_training_restriction/);
});

test('managed squad is excluded from legacy weekly recovery and injury ownership',()=>{
  assert.match(recovery,/create or replace function public\.apply_world_recovery_week_v24/);
  assert.match(recovery,/managed_players_restored/);
  assert.match(recovery,/create or replace function public\.simulate_injuries_week_v24/);
  assert.match(recovery,/managed_injuries_filtered/);
  assert.match(backend,/db\.rpc\("simulate_injuries_week_v24"/);
  assert.match(backend,/db\.rpc\("apply_world_recovery_week_v24"/);
});

test('weekly medical pass is plan and finance summary only, not a second condition mutation',()=>{
  assert.match(recovery,/'fatigue_delta',0/);
  assert.match(recovery,/'fitness_delta',0/);
  assert.match(recovery,/'condition_owner','CB-DAILY-RECOVERY-v24'/);
  assert.match(recovery,/'budget_owner','weekly_checkpoint_finance_ledger'/);
  assert.doesNotMatch(recovery,/set budget=budget-cost/);
});

test('daily UI exposes post-match recovery travel and medical restriction',()=>{
  assert.doesNotThrow(()=>new Function(daily));
  assert.match(daily,/Récupération nuit/);
  assert.match(daily,/Dette post-match/);
  assert.match(daily,/Récupération post-match/);
  assert.match(daily,/Staff médical : entraînement remplacé/);
  assert.match(daily,/playerRecovery\?\.travel_applied/);
  assert.match(play,/daily-career-v22\.js\?v=20261004-post-match-recovery-v24/);
});


test('V24 recovery has one physical owner and training only reads residual debt',()=>{
  assert.doesNotMatch(trainingOwner,/managed_post_match_recovery_context_v23/);
  assert.doesNotMatch(trainingOwner,/post_match_recovery_debt\s*=/);
  assert.doesNotMatch(trainingOwner,/travel_recovery_debt\s*=/);
  assert.match(trainingOwner,/select[\s\S]*post_match_recovery_debt[\s\S]*travel_recovery_debt[\s\S]*into v_post_match_debt,v_travel_debt/);
  assert.match(trainingOwner,/'recovery_owner','CB-DAILY-RECOVERY-v24'/);
  assert.match(trainingOwner,/v_debt_training_mult/);
  assert.match(trainingOwner,/v_overreach_penalty/);
  assert.match(trainingOwner,/'model','CB-DAILY-TRAINING-v24'/);
});
