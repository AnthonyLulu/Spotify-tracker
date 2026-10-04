import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const hof=read('supabase/migrations/20261004214439_hof_retirement_fastpath_v37.sql');
const ranks=read('supabase/migrations/20261004214721_career_rank_nullable_v38.sql');
const rollover=read('supabase/migrations/20261004215800_rollover_differential_ability_id_fix_v40.sql');

test('mass retirement HOF registration is player-scoped, not a global leaderboard per retiree',()=>{
  assert.match(hof,/CB-HOF-RETIREMENT-v2-fast/);
  assert.match(hof,/rank_deferred_to_hof_cycle/);
  assert.match(hof,/pt\.player_id=p_player_id/);
  assert.match(hof,/s\.player_id=p_player_id/);
  assert.doesNotMatch(hof,/from public\.court_boss_legacy_leaderboard/);
});

test('managed career can become unranked without breaking season rollover',()=>{
  assert.match(ranks,/singles_rank drop not null/);
  assert.match(ranks,/doubles_rank drop not null/);
});

test('year rollover only updates abilities that actually change',()=>{
  assert.match(rollover,/with ability_changes as/);
  assert.match(rollover,/current_ability is distinct from a\.new_current_ability/);
  assert.match(rollover,/potential is distinct from a\.new_potential/);
  assert.match(rollover,/p\.id=cg\.player_id/);
});
