import test from 'node:test';
import assert from 'node:assert/strict';
import {validDoublesEventDate,doublesEventWindow,readDoublesEventSql,executeOneDoublesEventSql,options,runDoublesStage}
 from '../qa/world-2050/stage-doubles-one-event-v101.mjs';

const stageDsn='postgresql://staging:secret@db.sozrygjxjotozrsenred.supabase.co:5432/postgres?sslmode=require';

test('time window selects precisely one event date and refuses invalid/outside-2026 days',()=>{
 assert.deepEqual(doublesEventWindow('2026-01-31'),{fromDate:'2026-01-30',toDate:'2026-01-31'});
 assert.deepEqual(doublesEventWindow('2026-03-01'),{fromDate:'2026-02-28',toDate:'2026-03-01'});
 for(const d of ['2050-01-31','2026-02-30','2025-12-01','2026-13-01','2026-1-1','2026-01-01']){
  assert.throws(()=>validDoublesEventDate(d));
 }
 assert.deepEqual(options(['--date=2026-01-31']),{date:'2026-01-31',execute:false});
 assert.equal(options(['--date=2026-01-31','--execute']).execute,true);
 assert.throws(()=>options(['--date=2026-01-31','--force']));
});

test('no authorization defaults to a read-only operator',async()=>{
 const calls=[];
 const r=await runDoublesStage({date:'2026-01-31',dsn:stageDsn,query:async ({sql})=>{
  calls.push(sql);
  return {mode:'STAGE_READ_ONLY',pending_events:1};
 }});
 assert.equal(r.mode,'STAGE_READ_ONLY');
 assert.equal(calls.length,1);
 assert.doesNotMatch(calls[0],/public\.simulate_world_doubles_tournaments\(/);
});

test('the event operator refuses unintended project credentials',async()=>{
 await assert.rejects(()=>runDoublesStage({
  date:'2026-01-31',execute:true,
  dsn:'postgresql://staging:pass@db.production.example/postgres',query:async()=>({ok:true})
 }),/Refusing/);
});

test('unified world guard is fail-closed for active saves, busy jobs and unexpected draws',()=>{
 const s=executeOneDoublesEventSql('2026-01-31');
 assert.match(s,/^BEGIN;/);
 assert.match(s,/SET LOCAL statement_timeout='65000ms'/);
 assert.match(s,/to_regclass\('cb_e2e_checkpoint_20261010.players'\)/);
 assert.match(s,/FROM public\.game_save_slots/);
 assert.match(s,/FROM public\.career_state/);
 assert.match(s,/WHERE status<>'completed'/);
 assert.match(s,/pg_try_advisory_xact_lock\(94832021\)/);
 assert.match(s,/IF n<>1 THEN/);
 assert.match(s,/status='completed' AND to_date >= DATE '2026-01-31'/);
 assert.match(s,/simulate_world_doubles_tournaments\(DATE '2026-01-30',DATE '2026-01-31'\)/);
 assert.match(s,/RAISE EXCEPTION 'Refuse doubles: ranking points missing'/);
 assert.match(s,/RAISE EXCEPTION 'Refuse doubles: final score \/ champion mismatch'/);
 assert.match(s,/^COMMIT;$/m);
 assert.match(s,/'2050_certified',false/);
});

test('SQL execution is explicit, per-day, transactionally validated, and no schedule is installed',async()=>{
 const calls=[];
 await runDoublesStage({date:'2026-01-31',execute:true,dsn:stageDsn,query:async ({sql})=>{
  calls.push(sql);return {ok:true,scope:'isolated_world_doubles_one_event'};
 }});
 assert.equal(calls.length,1);
 assert.match(calls[0],/CREATE TEMP TABLE cb_p0_doubles_result ON COMMIT DROP/);
 assert.match(calls[0],/DO \$verify\$/);
 const inspect=readDoublesEventSql('2026-01-31');
 assert.match(inspect,/NOT EXISTS\(SELECT 1 FROM public.world_doubles_tournament_simulations/);
 assert.match(inspect,/'running_world_jobs'/);
});
