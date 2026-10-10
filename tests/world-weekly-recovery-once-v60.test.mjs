import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010111500_world_weekly_recovery_once_v60.sql',import.meta.url),'utf8');
const original=fs.readFileSync(new URL('../qa/world-2050/world-recovery-previous-v60.sql',import.meta.url),'utf8');
const probe=fs.readFileSync(new URL('../qa/world-2050/stage-world-weekly-recovery-idempotence-v60.sql',import.meta.url),'utf8');
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');

test('global world weekly recovery runs only once per date, including simultaneous retry',()=>{
 assert.match(sql,/pg_advisory_xact_lock\(94832021\)/);
 assert.match(sql,/where e\.event_type='world_weekly_recovery_v60' and e\.event_date=p_date/i);
 assert.match(sql,/career_event_log_world_recovery_once_v60/);
 assert.match(sql,/UNIQUE INDEX IF NOT EXISTS/);
 assert.match(sql,/WHERE event_type='world_weekly_recovery_v60'/);
 assert.match(sql,/'already_applied',true/);
 assert.match(sql,/'updated_players',0,'already_applied',true/);
});
test('weekly recovery marker shares a PostgreSQL transaction with fatigue and fitness',()=>{
 assert.match(sql,/update public\.players p/);
 assert.match(sql,/insert into public\.career_event_log\(/);
 assert.ok(sql.indexOf('update public.players p')<sql.indexOf('insert into public.career_event_log('));
 assert.match(sql,/get diagnostics v_count=row_count/);
 assert.match(sql,/'updated_players',v_count/);
 assert.match(original,/public\.apply_world_recovery_week/);
 assert.match(original,/set fatigue=greatest/);
});
test('the existing restore/snapshot includes the exact world recovery event table',()=>{
 const start=edge.indexOf('async function captureManagedSaveSnapshot()');
 const stop=edge.indexOf('async function ensureCareerBaselineTemplate()',start);
 const code=edge.slice(start,stop);
 assert.ok(start>0 && stop>start);
 assert.match(code,/db\.from\("career_event_log"\)\.select\("\*"\)/);
 assert.match(code,/career_event_log/);
});
test('isolated live SQL QA injects fatigue, compares two calls, then forces full rollback',()=>{
 assert.match(probe,/fatigue=80,fitness=60 WHERE id=1/);
 assert.match(probe,/apply_world_recovery_week\(date '2026-01-11',2\)/);
 assert.match(probe,/apply_world_recovery_week\(date '2026-01-11',99\)/);
 assert.match(probe,/first_fatigue<>second_fatigue/);
 assert.match(probe,/n<>1/);
 assert.match(probe,/CB_WORLD_RECOVERY_FORCE_ROLLBACK/);
 assert.match(probe,/REVOKE ALL ON FUNCTION/);
});
