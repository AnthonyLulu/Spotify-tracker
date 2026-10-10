import test from 'node:test';
import assert from 'node:assert/strict';
import {advanceIsolatedSinglesWeeks,assertStageSinglesWeekReceipt} from '../qa/world-2050/resumable-singles-weeks-v85.mjs';

function makeStage({start='2026-01-25',events=16,completed=4,busyOnce=false,invalidReceipt=false}={}){
 const weeks=new Map();
 const firstKey='WORLD-SINGLES:'+start+':2026-02-01';
 weeks.set(firstKey,{job_key:firstKey,status:'running',expected_items:events,completed_items:completed});
 let calls=0,beginCalls=0,saveCalls=0,busy=busyOnce;
 return {
  stats:()=>({calls,beginCalls,saveCalls,first:weeks.get(firstKey)}),
  async assertStageIsolated(){return {ok:true,environment:'isolated_staging',user_saves:0,active_careers:0}},
  async getWeekStatus({key}){return weeks.has(key)?{...weeks.get(key)}:null},
  async beginWeek({key}){beginCalls++;weeks.set(key,{job_key:key,status:'running',expected_items:2,completed_items:0});return {ok:true,job_key:key,expected:2};},
  async stepWeek({key}){
   calls++;
   if(busy){busy=false;return {ok:false,retryable:true,reason:'busy'};}
   const w=weeks.get(key);
   if(w.completed_items===w.expected_items){w.status='completed';return {ok:true,done:true,completed:w.completed_items};}
   w.completed_items++;
   return {ok:true,done:w.completed_items===w.expected_items,completed:w.completed_items};
  },
  async readWeekReceipt({key}){
   const w=weeks.get(key),date=key.slice(-10),n=w.expected_items;
   return {ok:!invalidReceipt,scope:'world_singles_only',certifies_full_unified_week:false,
    world_run_id:key,checkpoint_date:date,status:w.status,
    world_simulation_committed:true,checkpoint_persisted:true,
    ranking_integrity_ok:true,nested_guard_ok:true,outer_guard_ok:true,
    tournaments_expected:n,tournaments_completed:n,
    matches_due:n*31,matches_committed:n*31,
    point_awards_expected:n*16,point_awards_recorded:n*16,
    invalid_event_rows:0,duplicate_match_effects:0,ranking_duplicates:0,managed_matches_pending:0};
  }
 };
}
const period={fromDate:'2026-01-25',throughDate:'2026-02-01'};

test('restart on fourth week resumes 4/16, never recreates or replays the completed events',async()=>{
 const a=makeStage();
 const r=await advanceIsolatedSinglesWeeks({adapter:a,...period,maxSteps:20});
 assert.equal(r.status,'SINGLES_WINDOW_VERIFIED_NOT_2050_CERTIFIED');
 assert.equal(r.weeksVerified,1);assert.equal(r.tournamentsVerified,16);
 assert.equal(r.matchesVerified,496);
 assert.equal(a.stats().beginCalls,0);
 assert.equal(a.stats().calls,13); // remaining 12 events + finalization-only call
 const retry=await advanceIsolatedSinglesWeeks({adapter:a,...period,maxSteps:1});
 assert.equal(retry.weeksVerified,1);assert.equal(a.stats().calls,13);
});

test('a bounded invocation exits after two committed events, then resumes safely',async()=>{
 const a=makeStage();
 const first=await advanceIsolatedSinglesWeeks({adapter:a,...period,maxSteps:2});
 assert.equal(first.status,'PAUSED_NOT_2050_CERTIFIED');
 assert.equal(first.serverSteps,2);assert.equal(first.pendingItems,10);
 const second=await advanceIsolatedSinglesWeeks({adapter:a,...period,maxSteps:20});
 assert.equal(second.weeksVerified,1);assert.equal(a.stats().calls,13);
});

test('busy lock never causes an uncontrolled retry or a write',async()=>{
 const a=makeStage({busyOnce:true});
 const r=await advanceIsolatedSinglesWeeks({adapter:a,...period,maxSteps:10});
 assert.equal(r.status,'BLOCKED_BUSY_NOT_CERTIFIED');
 assert.equal(r.serverSteps,0);assert.equal(a.stats().calls,1);
 assert.equal(a.stats().first.completed_items,4);
});

test('missing source, fake stage, or active user saves block all world writes',async()=>{
 const a=makeStage();
 a.assertStageIsolated=async()=>({ok:true,environment:'isolated_staging',user_saves:119,active_careers:0});
 await assert.rejects(()=>advanceIsolatedSinglesWeeks({adapter:a,...period}),/preflight failed/);
 assert.equal(a.stats().calls,0);
});

test('tampered winner/point/rank receipt fails even when all events completed',async()=>{
 for(const field of ['ranking_integrity_ok','nested_guard_ok','outer_guard_ok','ok']){
  const a=makeStage({completed:16});
  const original=a.readWeekReceipt.bind(a);
  a.readWeekReceipt=async params=>({...await original(params),[field]:false});
  a.stats().first.status='completed';
  // The test adapter's status is a copy; return a completed row from the DB mock.
  const getter=a.getWeekStatus.bind(a);
  a.getWeekStatus=async params=>({...await getter(params),status:'completed'});
  await assert.rejects(()=>advanceIsolatedSinglesWeeks({adapter:a,...period}),/Unverified singles world-week/);
 }
});

test('a singles receipt can never claim fully unified world certification',()=>{
 const key='WORLD-SINGLES:2026-01-25:2026-02-01';
 assert.throws(()=>assertStageSinglesWeekReceipt({
   ok:true,scope:'full_unified_world',certifies_full_unified_week:true,
   world_run_id:key,checkpoint_date:'2026-02-01'
 },{key,toDate:'2026-02-01',expectedItems:16}),/Unverified/);
});

test('preflight rejects windows outside certified 2026 Sundays',async()=>{
 const a=makeStage();
 await assert.rejects(()=>advanceIsolatedSinglesWeeks({adapter:a,fromDate:'2026-01-26',throughDate:'2026-02-01'}),/Sunday-to-Sunday/);
 await assert.rejects(()=>advanceIsolatedSinglesWeeks({adapter:a,fromDate:'2026-12-27',throughDate:'2050-12-31'}),/Sunday-to-Sunday/);
 assert.equal(a.stats().calls,0);
});
