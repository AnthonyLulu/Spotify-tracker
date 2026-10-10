// Court Boss isolated-staging world-singles driver.
// This is an *adapter-only* deterministic controller: no Supabase secrets,
// HTTP client, local saves, database connections or scheduler are bundled.
// A real adapter must call the existing isolated stage begin_world_week_v2,
// step_world_week_v2, verify_persisted_singles_week_v80 and READ job status.
// This verifies ATP/Challenger/ITF singles ONLY, never full 2050 eligibility.
import {isoDay,nextDay} from './replay-controller.mjs';

function nextWeek(date){
 let result=date;
 for(let i=0;i<7;i++)result=nextDay(result);
 return result;
}
function positiveInt(x){return Number.isSafeInteger(x)&&x>0;}
function nonNegativeInt(x){return Number.isSafeInteger(x)&&x>=0;}

export function assertStageSinglesWeekReceipt(r,{key,toDate,expectedItems}){
 if(r?.ok!==true || r.scope!=='world_singles_only'
   || r.certifies_full_unified_week!==false
   || r.world_run_id!==key || r.checkpoint_date!==toDate
   || r.status!=='completed'
   || r.world_simulation_committed!==true
   || r.checkpoint_persisted!==true
   || r.ranking_integrity_ok!==true
   || r.nested_guard_ok!==true
   || r.outer_guard_ok!==true
   || !positiveInt(r.tournaments_expected)
   || r.tournaments_expected!==expectedItems
   || r.tournaments_completed!==expectedItems
   || !positiveInt(r.matches_due)
   || r.matches_committed!==r.matches_due
   || !positiveInt(r.point_awards_expected)
   || r.point_awards_recorded!==r.point_awards_expected
   || ![r.invalid_event_rows,r.duplicate_match_effects,r.ranking_duplicates,
        r.managed_matches_pending].every(x=>x===0)){
  throw Error('Unverified singles world-week result: '+key);
 }
 return r;
}

function checkWeekState(state,key){
 if(state===null)return null;
 if(typeof state!=='object'||state.job_key!==key
   || !['running','completed'].includes(state.status)
   || !nonNegativeInt(state.expected_items)
   || !nonNegativeInt(state.completed_items)
   || state.completed_items>state.expected_items){
  throw Error('Invalid or inconsistent persisted week state: '+key);
 }
 return state;
}

// Strictly sequenced across Sundays, with bounded mutations per invocation.
// No attempt to retry a server busy lock or an ambiguous transaction failure.
// On restarting, getWeekStatus() is authoritative: existing completed events
// are NEVER played twice and the finalization-only last step is handled.
export async function advanceIsolatedSinglesWeeks({
 adapter,fromDate='2026-01-25',throughDate='2026-02-22',
 maxSteps=4,maxWeeks=53,onProgress=()=>{}
}={}){
 if(!adapter || typeof adapter!=='object')throw Error('Missing isolated world adapter');
 for(const method of ['assertStageIsolated','getWeekStatus','beginWeek','stepWeek','readWeekReceipt']){
  if(typeof adapter[method]!=='function')throw Error('Missing required isolated world method: '+method);
 }
 const from=isoDay(fromDate),to=isoDay(throughDate);
 if(from.getUTCDay()!==0||to.getUTCDay()!==0
   || fromDate>='2027-01-01' || fromDate<'2026-01-04'
   || throughDate>'2026-12-31' || fromDate>=throughDate){
  throw Error('Stage-only 2026 Sunday-to-Sunday window required');
 }
 if(!positiveInt(maxSteps)||maxSteps>1000||!positiveInt(maxWeeks)||maxWeeks>53){
  throw Error('Invalid bounded world replay budget');
 }
 // Independent server-side test adapter MUST inspect saves, careers, scope,
 // advisory locks and original world seed, not return a fabricated boolean.
 const preflight=await adapter.assertStageIsolated();
 if(preflight?.ok!==true || preflight.environment!=='isolated_staging'
   || preflight.user_saves!==0 || preflight.active_careers!==0){
  throw Error('Isolated stage preflight failed: real user saves or careers may exist');
 }
 const result={status:'PAUSED_NOT_2050_CERTIFIED',scope:'world_singles_only',
   startedFrom:fromDate,throughDate,weeksVerified:0,tournamentsVerified:0,
   matchesVerified:0,rankingAwardRowsVerified:0,serverSteps:0,
   lastVerifiedWeekEnd:null,firstUnfinishedWeek:null};
 let weekStart=fromDate;
 for(let weeks=0;weeks<maxWeeks && weekStart<throughDate;weeks++){
  const weekEnd=nextWeek(weekStart);
  if(weekEnd>throughDate)break;
  const key='WORLD-SINGLES:'+weekStart+':'+weekEnd;
  let state=checkWeekState(await adapter.getWeekStatus({key}),key);
  if(!state){
   const begin=await adapter.beginWeek({fromDate:weekStart,toDate:weekEnd,key});
   if(begin?.ok!==true || begin.job_key!==key
       || !nonNegativeInt(begin.expected))throw Error('Unable to begin world week '+key);
   state=checkWeekState(await adapter.getWeekStatus({key}),key);
   if(!state)throw Error('New world week was not persisted: '+key);
  }
  if(state.expected_items===0){
   // Single-scope empty calendar weeks need an independent verifier.
   // The currently deployed v80 receipt cannot certify them.
   throw Error('World week requires external calendar coverage proof: '+key);
  }
  const initialCount=state.completed_items;
  if(state.status!=='completed'){
   for(;;){
    if(result.serverSteps>=maxSteps){
     result.firstUnfinishedWeek=key;
     result.pendingItems=state.expected_items-state.completed_items;
     return result;
    }
    const step=await adapter.stepWeek({key});
    if(step?.ok!==true){
     if(step?.retryable===true&&step.reason==='busy'){
      result.status='BLOCKED_BUSY_NOT_CERTIFIED';
      result.firstUnfinishedWeek=key;
      result.pendingItems=state.expected_items-state.completed_items;
      return result;
     }
     throw Error('World step failed, stop without replay: '+key+' '+(step?.reason||'unverified'));
    }
    result.serverSteps++;
    const latest=checkWeekState(await adapter.getWeekStatus({key}),key);
    if(!latest||latest.completed_items<state.completed_items
      || latest.expected_items!==state.expected_items
      || latest.completed_items>state.completed_items+1){
     throw Error('World step caused unverified event jump or regression: '+key);
    }
    if(step.already_completed!==true && latest.status!=='completed'
      && latest.completed_items===state.completed_items){
     // A finalizer is only allowed at the end of all scheduled events.
     if(state.completed_items!==state.expected_items){
      throw Error('World step did not persist an event: '+key);
     }
    }
    state=latest;
    if(state.status==='completed')break;
   }
  }
  const receipt=assertStageSinglesWeekReceipt(
   await adapter.readWeekReceipt({key}),{key,toDate:weekEnd,expectedItems:state.expected_items});
  result.weeksVerified++;
  result.tournamentsVerified+=receipt.tournaments_completed;
  result.matchesVerified+=receipt.matches_committed;
  result.rankingAwardRowsVerified+=receipt.point_awards_recorded;
  result.lastVerifiedWeekEnd=weekEnd;
  onProgress({key,previouslyCommittedItems:initialCount,verified:receipt});
  weekStart=weekEnd;
 }
 if(weekStart===throughDate){
  result.status='SINGLES_WINDOW_VERIFIED_NOT_2050_CERTIFIED';
 } else if(weekStart<throughDate){
  result.firstUnfinishedWeek='WORLD-SINGLES:'+weekStart+':'+nextWeek(weekStart);
 }
 return result;
}
