import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const app=fs.readFileSync('court-boss/app.js','utf8');
const css=fs.readFileSync('court-boss/app.css','utf8');
const edge=fs.readFileSync('supabase/functions/court-boss/index.ts','utf8');
const workflow=fs.readFileSync('.github/workflows/court-boss-pages.yml','utf8');
const migrations=fs.readdirSync('supabase/migrations').filter(x=>x.includes('audit_reliability_v31')).map(x=>fs.readFileSync('supabase/migrations/'+x,'utf8')).join('\n');

test('one accessible write gate replaces the native prompt',()=>{
  assert.doesNotMatch(app,/prompt\(['"]Code d’accès Court Boss/);
  assert.match(app,/requestCourtBossAccess/);
  assert.match(app,/api\/access-check/);
  assert.match(css,/\.cb-access-gate/);
});
test('reads do not proactively request a code',()=>{
  assert.match(app,/const key=accessKey;/);
  assert.match(app,/r=await fetch\(API\+path/);
  assert.doesNotMatch(app,/const key=courtBossAccessKey\(\)/);
});
test('save v8 covers records and Hall of Fame timeline',()=>{
  assert.match(edge,/CB-MANAGED-SAVE-v8/);
  for(const table of ['record_occurrences','court_boss_match_stat_lines','court_boss_player_awards','court_boss_hof_profiles','court_boss_hof_classes','court_boss_retirement_ceremonies']) assert.match(edge,new RegExp(table));
  assert.match(edge,/rollback_recovered/);
});
test('writes are authenticated and serialized',()=>{
  assert.match(edge,/cb_write_access_digest_v31/);
  assert.match(edge,/cb_acquire_write_lock_v31/);
  assert.match(edge,/cb_release_write_lock_v31/);
  assert.match(edge,/api\/access-check/);
});
test('AI boxscores scale 1..20 game attributes before 0..100 formulas',()=>{
  assert.match(migrations,/cb_attr100_v31/);
  assert.match(migrations,/CB-WORLD-BOXSCORE-v2-scale20/);
});
test('CI runs the complete Node regression suite',()=>{
  assert.match(workflow,/node --test tests\/\*\.test\.mjs/);
});
