import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const root=new URL('../supabase/migrations/',import.meta.url);
const read=name=>fs.readFileSync(new URL(name,root),'utf8');

const base=read('20261003175457_atp_commitment_world_health_v18.sql');
const canonical=read('20261003175912_fix_atp_commitment_canonical_players_v18.sql');
const projection=read('20261003180115_fix_atp500_projection_sequential_v18.sql');
const guard=read('20261003180342_fix_world_guard_calendar_scope_v18.sql');
const security=read('20261003180513_secure_atp_commitment_rules_v18.sql');

test('ATP 2026 commitment rule is data-driven and keeps Monte-Carlo semantics separate',()=>{
  assert.match(base,/2026,30,4,1,4,3,true,false,true/);
  assert.match(base,/atp_commitment_rules_v18/);
  assert.match(base,/monte_carlo_counts_for_commitment/);
  assert.match(base,/monte_carlo_counts_for_bonus/);
});

test('ATP 500 planning covers three swings plus a fourth event without same-week duplication',()=>{
  assert.match(base,/atp500_commitment_plan_v18/);
  assert.match(base,/partition by s\.swing_no/);
  assert.match(base,/date_trunc\('week',p\.start_date::timestamp\)=date_trunc\('week',s\.start_date::timestamp\)/);
  assert.match(base,/v_in_atp500_plan/);
  assert.match(base,/v_remaining_post_uso_500/);
});

test('Commitment roster excludes hidden duplicate identities',()=>{
  assert.match(canonical,/p\.ranking_current=true/);
  assert.match(canonical,/hidden duplicate merged into %/);
  assert.match(canonical,/atp_commitment_players_v18/);
});

test('Projection resolves concurrent ATP 500 choices per player-week',()=>{
  assert.match(projection,/partition by i\.player_id,date_trunc\('week',i\.start_date::timestamp\)/);
  assert.match(projection,/week_choice=1/);
  assert.match(projection,/i\.planned desc/);
});

test('World health validates a bounded near-term window and a separate 25-year horizon',()=>{
  assert.match(guard,/interval '2 years'/);
  assert.match(guard,/world_25y_validation_v18/);
  assert.match(guard,/calendar_duplicate_groups/);
  assert.match(guard,/between p_start_year and p_end_year/);
});

test('ATP commitment rule table remains backend-only',()=>{
  assert.match(base,/revoke all on table public\.atp_commitment_rules_v18 from anon, authenticated/);
  assert.match(security,/to service_role/);
  assert.match(security,/using \(true\)/);
});
