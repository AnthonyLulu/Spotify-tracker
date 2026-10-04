import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const supply=read('supabase/migrations/20261003191500_living_world_supply_v16.sql');
const repair=read('supabase/migrations/20261003192500_living_world_integrity_repair_v16.sql');
const ranking=read('supabase/migrations/20261003193000_ranking_lifecycle_integrity_v16.sql');
const staff=read('supabase/migrations/20261003205448_staff_lifecycle_v21_no_immortals.sql');
const audit=read('supabase/migrations/20261003210327_staff_world_integrity_audit_v21.sql');

test('career horizon keeps a read-only 2026-2050 stress model',()=>{
  assert.match(supply,/living_world_stress_test_v16/);
  assert.match(supply,/p_start_year integer DEFAULT 2026/);
  assert.match(supply,/p_end_year integer DEFAULT 2050/);
  assert.match(supply,/adult_floor/);
  assert.match(supply,/replenishment_capacity/);
  assert.match(supply,/maintain_world_player_supply_v16/);
});

test('retired players cannot remain in active world ranking and future entries',()=>{
  for(const marker of [
    'retired_rank_state_fixed','world_entries_removed','retired_injuries_closed',
    'retired_world_rank','duplicate_active_world_rank','future_retired_entries'
  ]) assert.ok((repair+'\n'+ranking).includes(marker),'missing '+marker);
});

test('ranking lifecycle has newgens and player career lifecycle refresh',()=>{
  for(const marker of ['newgen_first','newgen_last','refresh_player_career_lifecycle','refresh_world_rankings'])
    assert.ok(ranking.includes(marker),'missing '+marker);
});

test('staff lifecycle has retirement dates and no immortal active staff',()=>{
  for(const marker of [
    'retirement_year','refresh_staff_lifecycle_v14','staff_without_retirement',
    'retired_staff_still_assigned','overdue_retiring_staff','staff_supply_low'
  ]) assert.ok((staff+'\n'+audit).includes(marker),'missing '+marker);
});
