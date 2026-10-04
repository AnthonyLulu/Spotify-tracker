import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');
const daily=read('court-boss/daily-career-v22.js');
const clock=read('supabase/migrations/20261004010328_daily_match_ticket_reserve_on_resume_v22.sql');
const due=read('supabase/migrations/20261004003544_managed_due_match_world_identity_v22.sql');
const matchDay=read('supabase/migrations/20261004120000_match_day_training_neutral_v23.sql');
const backend=read('supabase/functions/court-boss/index.ts');

test('daily career advances one calendar day and sends the next-day plan',()=>{
  assert.match(daily,/function nextDate\(\)\{return isoDatePlus\(String\(local\.date\|\|career\(\)\?\.career_date\|\|'2025-12-01'\),1\)\}/);
  assert.match(daily,/function nextDayIndex\(\)\{return isoDow\(nextDate\(\)\)-1\}/);
  assert.match(clock,/v_to:=v_from\+1/);
  assert.match(clock,/apply_managed_training_day_v22/);
});

test('match day is reserved for Match Center instead of being simulated by daily training',()=>{
  assert.match(clock,/'morning','Échauffement'/);
  assert.match(clock,/'afternoon','Match'/);
  assert.match(clock,/'automatic_match_day',true/);
  assert.match(clock,/'competitive_load_owner','match_center'/);
  assert.match(matchDay,/v_competitive_match_day:=lower\(v_sessions\[1\]\) in \('échauffement','echauffement'\)/);
  assert.match(matchDay,/and lower\(v_sessions\[2\]\)='match'/);
});

test('automatic match day adds no training XP, fatigue recovery, fitness boost or training injury',()=>{
  assert.match(matchDay,/when v_competitive_match_day and lower\(v_session\) in \('échauffement','echauffement','match'\) then 0/);
  assert.match(matchDay,/or \(v_competitive_match_day and lower\(v_session\) in \('échauffement','echauffement','match'\)\)/);
  assert.match(matchDay,/if v_competitive_match_day then[\s\S]*v_load:=0;/);
  assert.match(matchDay,/v_fatigue_after:=v_fatigue_before/);
  assert.match(matchDay,/v_fitness_after:=v_fitness_before/);
  assert.match(matchDay,/v_form_after:=v_form_before/);
  assert.match(matchDay,/v_morale_after:=v_morale_before/);
  assert.match(matchDay,/v_injury_risk:=0/);
  assert.match(matchDay,/v_training_niggle:=false/);
  assert.match(matchDay,/'competitive_load_owner',case when v_competitive_match_day then 'match_center' else 'training' end/);
});

test('Match Center remains the single owner of competitive condition changes',()=>{
  assert.match(backend,/const fatigueAdd=Math\.max\(4,Math\.min\(16,/);
  assert.match(backend,/managed_condition:managedUpdate/);
  assert.match(backend,/partner_condition:partnerUpdate/);
  assert.match(backend,/commit_live_world_match_atomic_v23/);
  assert.match(backend,/commit_live_doubles_world_match_atomic_v23/);
});

test('daily match tickets retain exact world-draw identity',()=>{
  assert.match(due,/matchup_components->>'status',''\)='managed_live_pending'/);
  assert.match(due,/'world_match_id',v_world_match_id,'opponent_id',v_opponent_id/);
  assert.match(due,/'world_match_id',v_world_match_id,'user_pair_id',v_user_pair_id/);
  assert.match(due,/'opponent_pair_id',v_opponent_pair_id/);
});
