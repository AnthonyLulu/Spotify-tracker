import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync(new URL('../supabase/migrations/20261010125300_weekly_rank_zero_points_no_null_career_v56.sql',import.meta.url),'utf8');
const client=fs.readFileSync(new URL('../court-boss/modules.js',import.meta.url),'utf8');
const probe=fs.readFileSync(new URL('../qa/world-2050/real-december-ten-day-sunday-probe-v56.sql',import.meta.url),'utf8');

test('world week rank update never writes NULL into required career rank',()=>{
 assert.match(migration,/public\.refresh_world_rankings\(p_date date/);
 assert.match(migration,/singles_rank=coalesce\(p\.ranking,c\.singles_rank\)/);
 assert.doesNotMatch(migration,/singles_rank=p\.ranking,career_date/);
 assert.match(migration,/p\.ranking=null/);
 assert.match(migration,/career_state\.singles_rank is NOT NULL/);
});
test('season button cannot accidentally invoke 2026 Jan-05 weekly path',()=>{
 assert.match(client,/new_year:next,daily_mode:true/);
 assert.match(client,/local\.date=boot\.career\?\.career_date\|\|local\.date/);
 assert.doesNotMatch(client,/local\.date=boot\.career\?\.career_date\|\|String\(next\)\+'-01-05'/);
});
test('ten daily ticks include real world simulation and a retried day',()=>{
 assert.match(probe,/public\.advance_career_day_v26/);
 assert.match(probe,/public\.simulate_world_week\(1,d\)/);
 assert.match(probe,/public\.mark_weekly_checkpoint_v22\(d\)/);
 assert.match(probe,/n_commits<>10 OR n_other<>1 OR n_checkpoints<>1/);
 assert.match(probe,/already_applied/);
 assert.match(probe,/CB_E2E_TEN_DAY_FORCE_ROLLBACK/);
 assert.match(probe,/pg_try_advisory_xact_lock\(2200261201\)/);
 assert.match(probe,/pg_try_advisory_xact_lock\(94832021\)/);
});
