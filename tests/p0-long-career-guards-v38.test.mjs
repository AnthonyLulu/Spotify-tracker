import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const hof=read('supabase/migrations/20261004214439_hof_retirement_fastpath_v37.sql');
const ranks=read('supabase/migrations/20261004214721_career_rank_nullable_v38.sql');

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
