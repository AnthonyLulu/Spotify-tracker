import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');

const recovery=read('supabase/migrations/20261004150000_post_match_conditioning_weather_v28.sql');
const training=read('supabase/migrations/20261004143000_post_match_recovery_single_owner_v27.sql');
const clock=read('supabase/migrations/20261004131500_daily_recovery_clock_v24.sql');
const backend=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');
const play=read('court-boss/play.html');

test('recovery debt now includes conditioning humidity and match-day delays',()=>{
  assert.match(recovery,/v_conditioning:=round\(\(v_stamina\*\.40\+v_recovery_attr\*\.25\+v_natural\*\.20\+v_athleticism\*\.15\)/);
  assert.match(recovery,/v_conditioning_mult:=greatest\(\.86,least\(1\.12,/);
  assert.match(recovery,/v_humidity\*\.45/);
  assert.match(recovery,/v_delay_minutes\/70\.0/);
  assert.match(recovery,/last_match_humidity_load/);
  assert.match(recovery,/last_match_delay_minutes/);
  assert.match(recovery,/last_match_conditioning_score/);
  assert.match(recovery,/'model','CB-RECOVERY-v28'/);
});

test('singles and doubles feed humidity and handled environmental delays into recovery',()=>{
  assert.match(backend,/const humidityLoad=Math\.max\(0,Number\(weather\.humidity_pct\|\|50\)-68\)\*\.03/);
  assert.match(backend,/environment_delay_minutes:Math\.round\(environmentDelayMinutes\)/);
  assert.match(backend,/const doublesHumidityLoad=Math\.max\(0,Number\(meta\.weather\?\.humidity_pct\|\|50\)-68\)\*\.025/);
  assert.match(backend,/environment_delay_minutes:Math\.round\(doublesDelayMinutes\)/);
});

test('daily recovery uses dedicated staff when present and truly falls back when absent',()=>{
  assert.match(recovery,/max\(sp\.medical_rating\*coalesce\(public\.staff_effectiveness_multiplier\(sp\.id\),1\)\)/);
  assert.match(recovery,/if coalesce\(v_medical,0\)<=0 or coalesce\(v_fitness_staff,0\)<=0 then/);
  assert.match(recovery,/from public\.staff s join public\.staff_profiles sp on sp\.id=s\.profile_id/);
  assert.doesNotMatch(recovery,/coalesce\(max\(sp\.medical_rating[\s\S]{0,120}\),10\),/);
});

test('single-owner rule survives the richer recovery model',()=>{
  assert.match(clock,/apply_managed_recovery_day_v24\(v_to,v_player_id\)/);
  assert.match(training,/when v_session='Récupération' then 0/);
  assert.match(training,/else 0\n    end;/);
  assert.match(training,/'competitive_load_owner',case when v_competitive_match_day then 'match_center' else 'training' end/);
  assert.match(training,/'recovery_owner','CB-DAILY-RECOVERY-v24'/);
});

test('manager UI exposes previous match load without adding another mutation path',()=>{
  assert.doesNotThrow(()=>new Function(app));
  assert.match(app,/last_match_minutes/);
  assert.match(app,/last_match_load/);
  assert.match(app,/last_match_humidity_load/);
  assert.match(app,/last_match_conditioning_score/);
  assert.match(play,/app\.js\?v=20261004-visual-assets-v33/);
});
