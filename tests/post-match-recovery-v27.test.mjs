import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const training=read('supabase/migrations/20261004143000_post_match_recovery_single_owner_v27.sql');
const recovery=read('supabase/migrations/20261004135000_recovery_return_travel_after_match_v25.sql');
const clock=read('supabase/migrations/20261004131500_daily_recovery_clock_v24.sql');
const backend=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');

test('daily recovery is the only passive physical recovery owner',()=>{
  assert.match(clock,/apply_managed_recovery_day_v24\(v_to,v_player_id\)/);
  assert.match(training,/when v_session='Récupération' then 0/);
  assert.match(training,/else 0\n    end;/);
  assert.doesNotMatch(training,/\(v_load-2\.0\)\*\.85/);
  assert.match(training,/round\(greatest\(0,least\(6,v_load\*\.78\)\)\)/);
  assert.match(training,/when v_load>=7 then -2/);
  assert.match(training,/'model','CB-DAILY-TRAINING-v27'/);
});

test('match day itself adds no second recovery before Match Center',()=>{
  assert.match(training,/if v_competitive_match_day then[\s\S]*v_load:=0;[\s\S]*v_fatigue_after:=v_fatigue_before;[\s\S]*v_fitness_after:=v_fitness_before;/);
  assert.match(training,/'competitive_load_owner',case when v_competitive_match_day then 'match_center' else 'training' end/);
});

test('match duration weather effort and doubles role create post-match debt once',()=>{
  assert.match(backend,/const durationMinutes=Math\.max\(40,Math\.min\(330,/);
  assert.match(backend,/const doublesDurationMinutes=Math\.max\(35,Math\.min\(240,/);
  assert.match(backend,/effort_load:Number\(effortLoad\.toFixed\(2\)\)/);
  assert.match(backend,/p_effect:"recovery_managed_v24"/);
  assert.match(backend,/p_effect:"recovery_partner_v24"/);
  assert.match(recovery,/live_match_effect_commits_v23/);
  assert.match(recovery,/already_applied/);
});

test('travel and medical staff feed one daily recovery pass',()=>{
  assert.match(recovery,/last_recovery_date is not null and v_load\.last_recovery_date>=v_date/);
  assert.match(recovery,/last_match_date<=v_date-1/);
  assert.match(recovery,/staff_effectiveness_multiplier/);
  assert.match(recovery,/travel_recovery_debt/);
  assert.match(recovery,/recommended_session/);
});

test('residual debt hurts training adaptation and raises risk without removing fatigue twice',()=>{
  assert.match(training,/v_recovery_pressure:=greatest\(0,least\(1,v_recovery_debt\/30\.0\)\)/);
  assert.match(training,/v_debt_training_mult:=greatest\(\.58,least\(1,1-v_recovery_debt\*\.014\)\)/);
  assert.match(training,/\*v_debt_training_mult;/);
  assert.match(training,/v_recovery_pressure\*\.22/);
  assert.match(training,/\+v_recovery_pressure\*8/);
});

test('training niggles become real short injuries and UI sees recovery state',()=>{
  assert.match(training,/insert into public\.injuries/);
  assert.match(training,/'Gêne musculaire','minor',v_date,v_date\+2/);
  assert.match(training,/'recovery_gain_multiplier',round\(v_debt_training_mult,3\)/);
  assert.match(app,/Bilan entraînement & récupération/);
  assert.match(app,/Dette post-match/);
});
