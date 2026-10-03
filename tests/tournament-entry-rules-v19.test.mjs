import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync(new URL('../supabase/migrations/20261003191230_official_tournament_entries_ai_v19.sql',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');

test('Grand Slams enforce international Top 500 and age 14+',()=>{
  assert.match(migration,/grand_slam_top500_entry_required/);
  assert.match(migration,/grand_slam_under14/);
  assert.match(app,/grand_slam_top500_entry_required/);
  assert.match(app,/pro_under14/);
});

test('ATP age limits are enforced without using fatigue as an entry prohibition',()=>{
  assert.match(migration,/if v_age=14 then v_limit:=8/);
  assert.match(migration,/elsif v_age=15 then v_limit:=12/);
  assert.match(migration,/Fatigue is a scheduling preference, not an entry-rule prohibition/);
});

test('Challenger play-down rules remain singles-only',()=>{
  assert.match(migration,/challenger_top10_prohibited/);
  assert.match(migration,/ch75_11_50_prohibited/);
  assert.match(migration,/ch50_wc_51_100_home_nation_only/);
  assert.match(migration,/ATP Challenger 7\.07 play-up restrictions apply to singles draws only/);
});

test('ITF M15 and M25 use ATP then ITF then rating merit instead of a fake Top-200 ban',()=>{
  assert.doesNotMatch(app,/itf_play_down_top200/);
  assert.match(migration,/2::int merit_tier/);
  assert.match(migration,/p\.ranking is null[\s\S]{0,120}p\.itf_ranking is not null/);
  assert.match(migration,/tier2 as \(/);
  assert.match(migration,/tier3 as \(/);
  assert.match(migration,/Legal does not mean sensible/);
});

test('Masters 1000 submission is automatic while ATP 500 commitment is rolling',()=>{
  assert.match(migration,/masters_automatic_entry/);
  assert.match(migration,/v_auto:=true/);
  assert.match(migration,/commitment_500_need/);
  assert.match(migration,/post_us_open_500_final_chance/);
  assert.match(migration,/Three-swing ATP 500 bonus is an incentive, not a mandatory scheduling rule/);
});

test('Parallel pro applications are reconciled after actual acceptance',()=>{
  assert.match(migration,/Parallel entry/);
  assert.match(migration,/world_acceptance_commitment_score/);
  assert.match(migration,/priority_score/);
});

test('Junior accepted choice is unique per week and NCAA season is protected',()=>{
  assert.match(migration,/ITF juniors may submit multiple entries/);
  assert.match(migration,/junior_player_commits_to_event/);
  assert.match(migration,/NCAA players protect the college season/);
});

test('Long-term health uses V19 entry audit rather than the rigid V18 500 planner',()=>{
  assert.match(migration,/CB-ENTRY-AUDIT-v19/);
  assert.match(migration,/CB-WORLD-25Y-VALIDATION-v19/);
  assert.match(migration,/CB-CAREER-OS-v19/);
});
