import test from 'node:test';
import assert from 'node:assert/strict';
import {advanceIsolatedSinglesWeeks} from '../qa/world-2050/resumable-singles-weeks-v85.mjs';

const fromDate='2026-03-15', throughDate='2026-03-22';
const key='WORLD-SINGLES:'+fromDate+':'+throughDate;

function makeAdapter({afterCommit=true,onFinalize=false,readFailure=false}={}) {
 const job={job_key:key,status:'running',expected_items:3,completed_items:onFinalize?3:1};
 let attempts=0, lost=true, started=0;
 const adapter={
  stats:()=>({attempts,started,job:{...job}}),
  async assertStageIsolated(){return {ok:true,environment:'isolated_staging',user_saves:0,active_careers:0};},
  async getWeekStatus(){if(readFailure&&attempts>0)throw Error('checkpoint read disconnected');return {...job};},
  async beginWeek(){started++;throw Error('must not recreate existing staged job');},
  async stepWeek(){
   attempts++;
   if(job.completed_items===job.expected_items){
    job.status='completed';
    if(lost){lost=false;throw Error('finalization response disconnected');}
    return {ok:true,done:true};
   }
   if(lost){
    lost=false;
    if(afterCommit)job.completed_items++;
    throw Error('TCP reset after an unknown transaction result');
   }
   job.completed_items++;
   return {ok:true,completed:job.completed_items};
  },
  async readWeekReceipt(){
   return {ok:true,scope:'world_singles_only',certifies_full_unified_week:false,
    world_run_id:key,checkpoint_date:throughDate,status:job.status,
    world_simulation_committed:true,checkpoint_persisted:true,ranking_integrity_ok:true,
    nested_guard_ok:true,outer_guard_ok:true,tournaments_expected:3,tournaments_completed:3,
    matches_due:93,matches_committed:93,point_awards_expected:48,point_awards_recorded:48,
    invalid_event_rows:0,duplicate_match_effects:0,ranking_duplicates:0,managed_matches_pending:0};
  }
 };
 return adapter;
}

test('lost response after commit must read checkpoint and stop without replaying event',async()=>{
 const a=makeAdapter();
 const result=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:5});
 assert.equal(result.status,'BLOCKED_AMBIGUOUS_NOT_CERTIFIED');
 assert.equal(result.ambiguousRequest,true);
 assert.equal(result.serverSteps,0);
 assert.equal(result.lastObservedCompletedItems,2);
 assert.equal(result.pendingItems,1);
 assert.equal(a.stats().attempts,1);
 assert.equal(a.stats().started,0);
 const resumed=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:5});
 assert.equal(resumed.status,'SINGLES_WINDOW_VERIFIED_NOT_2050_CERTIFIED');
 assert.equal(a.stats().job.completed_items,3);
 assert.equal(a.stats().attempts,3); // one ambiguous commit, one remaining event, one finalizer
 assert.equal(a.stats().started,0);
});

test('lost response before commit reports the durable count without auto retry',async()=>{
 const a=makeAdapter({afterCommit:false});
 const first=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:4});
 assert.equal(first.status,'BLOCKED_AMBIGUOUS_NOT_CERTIFIED');
 assert.equal(first.lastObservedCompletedItems,1);
 assert.equal(first.pendingItems,2);
 assert.equal(a.stats().attempts,1);
 const restart=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:4});
 assert.equal(restart.status,'SINGLES_WINDOW_VERIFIED_NOT_2050_CERTIFIED');
 assert.equal(a.stats().attempts,4);
});

test('lost response after finalization requires a later independent receipt',async()=>{
 const a=makeAdapter({onFinalize:true});
 const first=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:1});
 assert.equal(first.status,'BLOCKED_AMBIGUOUS_NOT_CERTIFIED');
 assert.equal(first.lastObservedCompletedItems,3);
 assert.equal(first.weeksVerified,0);
 const second=await advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:1});
 assert.equal(second.status,'SINGLES_WINDOW_VERIFIED_NOT_2050_CERTIFIED');
 assert.equal(a.stats().attempts,1);
});

test('no checkpoint response means fail closed and never make a second write',async()=>{
 const a=makeAdapter({readFailure:true});
 await assert.rejects(
  ()=>advanceIsolatedSinglesWeeks({adapter:a,fromDate,throughDate,maxSteps:5}),
  /checkpoint read disconnected/
 );
 assert.equal(a.stats().attempts,1);
});
