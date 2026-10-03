import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync(new URL('../supabase/migrations/20261003194545_official_doubles_entries_ai_v20.sql',import.meta.url),'utf8');
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');

test('ATP/Challenger doubles entry merit uses dated best singles or doubles rank',()=>{
  assert.match(migration,/doubles_player_entry_merit_v20/);
  assert.match(migration,/player_rank_at_date/);
  assert.match(migration,/player_doubles_seed_rank_at_date/);
  assert.match(migration,/doubles_team_entry_merit_v20/);
  assert.match(migration,/combined_rank/);
});

test('ITF M15 is 13 on-site plus 3 wild cards',()=>{
  assert.match(migration,/ITF 2026 M15 doubles/);
  assert.match(migration,/where rn<=13/);
  assert.match(migration,/where w\.rn<=3/);
});

test('ITF M25 is seven advance, six on-site and three wild cards in a 16-team draw',()=>{
  assert.match(migration,/ITF 2026 M25 doubles · advance entry/);
  assert.match(migration,/where rn<=7/);
  assert.match(migration,/13-\(select count\(\*\) from advance\)/);
  assert.match(migration,/ITF 2026 M25 doubles · wildcard/);
});

test('ATP 2026 pro selectors reserve real WC/on-site/qualifying positions',()=>{
  assert.match(migration,/select_pro_doubles_field_v20/);
  assert.match(migration,/v_q_da:=3/);
  assert.match(migration,/v_q_wc:=1/);
  assert.match(migration,/v_onsite:=least\(4/);
  assert.match(migration,/v_wc:=2/);
});

test('Masters 1000 automatic team entry requires team continuity',()=>{
  assert.match(migration,/doubles_m1000_auto_acceptance_v20/);
  assert.match(migration,/final_2025_top13_team_and_active_2026_pair/);
  assert.match(migration,/continuity_required/);
  assert.match(edge,/Admission automatique M1000/);
  assert.match(edge,/entry_method:"auto_direct"/);
});

test('managed doubles API distinguishes advance-only ATP from Challenger on-site',()=>{
  assert.match(edge,/String\(t\?\.circuit\)==="Challenger"\?"advance_then_onsite"/);
  assert.match(edge,/String\(t\?\.circuit\)==="ATP"\?"advance_only"/);
  assert.match(edge,/Advance entry double close/);
  assert.match(edge,/composition\.onsite/);
});

test('UI exposes official doubles entry phases',()=>{
  assert.match(app,/auto_direct:'Admission automatique'/);
  assert.match(app,/advance:'Advance Entry'/);
  assert.match(app,/onsite:'On-site'/);
  assert.match(app,/On-site · système de mérite/);
});

test('V20 doubles audit is part of long-horizon health',()=>{
  assert.match(migration,/CB-DOUBLES-ENTRY-AUDIT-v20/);
  assert.match(migration,/CB-WORLD-25Y-VALIDATION-v20/);
  assert.match(migration,/CB-CAREER-LONG-HORIZON-v20/);
  assert.match(migration,/CB-CAREER-OS-v20/);
});
