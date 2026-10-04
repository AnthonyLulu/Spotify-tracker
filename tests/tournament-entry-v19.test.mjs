import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const core=fs.readFileSync(new URL('../supabase/migrations/20261003191500_tournament_entry_rules_ai_v19.sql',import.meta.url),'utf8');
const builders=fs.readFileSync(new URL('../supabase/migrations/20261003191600_tournament_world_builders_v19.sql',import.meta.url),'utf8');
const ui=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');

test('V19 removes the invented ITF Top-200 play-down ban everywhere',()=>{
 assert.doesNotMatch(core,/itf_play_down_top200/);
 assert.doesNotMatch(builders,/itf_play_down_top200/);
 assert.doesNotMatch(ui,/M15\/M25 interdits au Top 200 ATP/);
});

test('ITF candidate order keeps ATP ahead of ITF-only merit and rating fallback',()=>{
 assert.match(core,/p\.ranking::int effective_rank,[\s\S]*1::int merit_tier/);
 assert.match(core,/2::int merit_tier,[\s\S]*p\.itf_ranking::numeric merit_value/);
 assert.match(core,/3::int merit_tier/);
 assert.match(core,/order by c\.merit_tier,c\.merit_value,c\.current_ability desc,c\.id/);
});

test('Grand Slam and junior-age guards are encoded in the authoritative entry arbiter',()=>{
 assert.match(core,/grand_slam_top500_entry_required/);
 assert.match(core,/grand_slam_under14/);
 assert.match(core,/atp_age_event_cap/);
});

test('Masters automatic entry and ATP 500 dynamic commitment logic are distinct',()=>{
 assert.match(core,/masters_automatic_entry/);
 assert.match(core,/commitment_500_need/);
 assert.match(core,/post_us_open_500_need/);
 assert.match(core,/Three-swing ATP 500 bonus is an incentive, not a mandatory scheduling rule/);
});

test('NCAA players use protected spring pro windows instead of a parallel full tour',()=>{
 assert.match(core,/ncaa-pro-window-v19/);
 assert.match(core,/v_ncaa_cadence:=case when v_rank<=250 then 3 else 4 end/);
 assert.match(core,/extract\(month from t\.start_date\) between 1 and 5/);
});

test('Singles Challenger play-down rules are not copied into doubles',()=>{
 assert.doesNotMatch(builders,/t\.circuit='Challenger' and coalesce\(p\.ranking,999999\)<=10 then return false/);
 assert.doesNotMatch(builders,/t\.circuit='ITF' and coalesce\(p\.ranking,999999\)<=200 then return false/);
});

test('Junior AI resolves one accepted event per week after interest generation',()=>{
 assert.match(core,/CB-JUNIOR-ENTRY-v19/);
 assert.match(core,/coalesce\(x\.main_draw_start_date,x\.start_date\) between v_week and v_week\+6/);
 assert.match(core,/return not v_better/);
});

test('UI fallback matches V19 pro-entry rules',()=>{
 assert.match(ui,/grand_slam_top500_entry_required/);
 assert.match(ui,/pro_under14/);
 assert.doesNotMatch(ui,/if\(t\.circuit==='ITF'.*rank<=200\)/);
});
