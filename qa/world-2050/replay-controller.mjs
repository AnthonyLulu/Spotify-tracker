// Deterministic orchestration contract for a real, isolated Court Boss 2050 replay.
// This module makes no network requests or database writes itself.
// The adapter MUST invoke real server-side game methods, not simplified stubs.
// No run is certifiable without independent schema parity + a full sanitized world seed.

export const isoDay = date => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(date))) throw Error('Invalid ISO date: '+date);
  const t = new Date(String(date)+'T00:00:00.000Z');
  if (!Number.isFinite(t.valueOf()) || t.toISOString().slice(0,10)!==date) throw Error('Invalid calendar date: '+date);
  return t;
};
export const nextDay = date => {
  const d=isoDay(date); d.setUTCDate(d.getUTCDate()+1); return d.toISOString().slice(0,10);
};
const quarterly=date=>{
 const d=isoDay(date); const m=d.getUTCMonth()+1;
 return ([3,6,9,12].includes(m) && nextDay(date).slice(5,7)!==date.slice(5,7));
};

// Real isolated adapters MUST prove their weekly world simulation and
// tournament reconciliation were durably committed. The clock watermark alone
// (mark_weekly_checkpoint_v22) is NOT proof that any AI match was played.
export function assertVerifiedWorldWeek(receipt,checkpointDate){
 if(receipt?.ok!==true
   // A passed ATP/Challenger/ITF singles job does NOT certify a full
   // NCAA/Davis/juniors/doubles/managed multi-circuit 2050 career week.
   || receipt.scope!=='full_unified_world'
   || receipt.world_simulation_committed!==true
   || receipt.checkpoint_persisted!==true
   || receipt.ranking_integrity_ok!==true
   || receipt.checkpoint_date!==checkpointDate
   || typeof receipt.world_run_id!=='string'
   || !receipt.world_run_id.trim()){
  throw Error('World week lacks verified simulation + durable checkpoint receipt for '+checkpointDate);
 }
 const due=receipt.matches_due;
 const resolved=receipt.matches_committed;
 const pending=receipt.managed_matches_pending;
 const duplicate=receipt.duplicate_match_effects;
 if(![due,resolved,pending,duplicate].every(n=>Number.isSafeInteger(n)&&n>=0)){
  throw Error('World week has no verified match-count reconciliation for '+checkpointDate);
 }
 if(resolved+pending!==due || duplicate!==0){
  throw Error('World week has missing or duplicated match effects for '+checkpointDate);
 }
 return receipt;
}

// The adapter must perform a genuine persistent save-slot write, end its game
// session, re-read/load the saved state, compare canonical full-state digests,
// and inject a failed-load rollback before returning this receipt. Offline
// mock receipts are only protocol tests, NEVER proof of mobile/API save/load.
export function assertVerifiedCareerSaveReload(receipt,date){
 const sha=x=>typeof x==='string' && /^[0-9a-f]{64}$/i.test(x);
 if(receipt?.ok!==true || receipt?.date!==date
   || receipt.slot_persisted!==true || receipt.session_reopened!==true
   || receipt.load_committed!==true || receipt.failed_load_rollback_verified!==true
   || receipt.snapshot_scope!=='full_career'
   || typeof receipt.slot_id!=='string' || !receipt.slot_id.trim()
   || !sha(receipt.before_sha256) || !sha(receipt.after_sha256)
   || receipt.before_sha256!==receipt.after_sha256){
  throw Error('Save/reload lacks persisted full-state roundtrip + rollback proof on '+date);
 }
 const fields=['duplicate_daily_commits','duplicate_match_effects','duplicate_recovery_effects',
 'date_skips','ranking_mismatches','career_state_mismatches'];
 if(fields.some(key=>!Number.isSafeInteger(receipt[key])||receipt[key]!==0)){
  throw Error('Save/reload changed or duplicated career state on '+date);
 }
 return receipt;
}

export async function replayIsolatedWorld({
  adapter, startDate='2025-12-01',endDate='2050-12-31',
  onProgress=()=>{},maxTransitions=15000
}={}){
 if (!adapter || typeof adapter!=='object') throw Error('Missing real-game adapter');
 isoDay(startDate); isoDay(endDate);
 if (startDate>=endDate) throw Error('Empty or reversed period');
 const required=['assertIsolatedEnvironment','assertSchemaParity','assertSeedReady',
  'acquireExclusiveReplayLease','releaseExclusiveReplayLease',
  'readCareerDate','advanceDay','runWeeklyCheckpoint','rolloverSeason',
  'playManagedMatch','probeSaveReload','verifyWorldInvariants'];
 for (const fn of required) if(typeof adapter[fn]!=='function')throw Error('Missing required real-world adapter: '+fn);
 // All guards run BEFORE the first mutating daily call.
 await adapter.assertIsolatedEnvironment();
 // Only a shared, durable lease enforced by the real DB adapter prevents
 // concurrent 25-year world replays. No silent in-memory fallback allowed.
 const lease=await adapter.acquireExclusiveReplayLease({startDate,endDate});
 if(lease?.acquired!==true || typeof lease.leaseId!=='string' || !lease.leaseId.trim()){
  throw Error('Exclusive isolated replay lease unavailable');
 }
 try{
 await adapter.assertSchemaParity();
 await adapter.assertSeedReady(startDate);
 const first=await adapter.readCareerDate();
 if(first!==startDate)throw Error('Starting world date mismatch: '+first+' / '+startDate);
 const report={status:'RUNNING_NOT_CERTIFIED',startDate,endDate,days:0,managedMatches:0,
  checkpoints:0,worldWeeksVerified:0,worldMatchesCommitted:0,rollovers:0,quarterlyChecks:0,saveLoadProbes:0,lastCommittedDate:startDate};
 let date=startDate;
 while(date<endDate){
  if(report.days>=maxTransitions)throw Error('Hard stop: maxTransitions exceeded at '+date);
  let response=null,committed=false;
  const seen=new Set();
  for(let attempts=0;attempts<12;attempts++){
   response=await adapter.advanceDay({expectedFromDate:date});
   if(response?.ok===true){
    if(response?.already_applied===true)throw Error('Unexpected already_applied for fresh day '+date);
    if(response.date!==nextDay(date))throw Error('Non-sequential day from '+date+': '+response?.date);
    committed=true;break;
   }
   const reason=response?.reason||response?.stop_reason||'unknown_failure';
   const phase=reason==='weekly_checkpoint_required'||response?.checkpoint_required ? 'checkpoint'
     : reason==='season_rollover_required'||response?.requires_rollover?'rollover'
     : reason==='pending_match'||response?.stop_reason==='match'?'match':null;
   if(!phase)throw Error('Day '+date+' rejected: '+reason);
   // A repeated condition without advancing the state means an infinite loop.
   const progressKey=phase+':'+date+':'+(response?.checkpoint_date||response?.new_year||JSON.stringify(response?.due_matches?.matches?.map(x=>x.id)||[]));
   if(seen.has(progressKey))throw Error('Unresolved repeat '+progressKey);
   seen.add(progressKey);
   if(phase==='checkpoint'){
    const checkpointDate=response.checkpoint_date||date;
    const weeklyReceipt=assertVerifiedWorldWeek(await adapter.runWeeklyCheckpoint({
     checkpointDate,
     fromDate:response.from_date,
     source:'pre_advance'
    }),checkpointDate);
    report.worldWeeksVerified++;
    report.worldMatchesCommitted+=weeklyReceipt.matches_committed;
    report.checkpoints++;
   }else if(phase==='rollover'){
    const nextYear=isoDay(nextDay(date)).getUTCFullYear();
    if(Number(response.new_year)!==nextYear)throw Error('Unexpected rollover year '+response.new_year);
    await adapter.rolloverSeason({newYear:nextYear,expectedFromDate:date});
    report.rollovers++;
   }else{
    await adapter.playManagedMatch({
     expectedFromDate:date,
     dueMatches:response.due_matches,
     source:'pre_advance'
    });
    report.managedMatches++;
   }
   if(await adapter.readCareerDate()!==date)throw Error('Pre-advance resolution changed date unexpectedly '+date);
  }
  if(!committed)throw Error('Day could not be committed after bounded resolutions '+date);
  const newDate=nextDay(date);
  if(await adapter.readCareerDate()!==newDate)throw Error('Committed day not stored '+newDate);
  date=newDate;report.days++;report.lastCommittedDate=date;
  if(response.weekly_checkpoint_due){
   const weeklyReceipt=assertVerifiedWorldWeek(await adapter.runWeeklyCheckpoint({
    checkpointDate:date,fromDate:response.week_start_date,source:'post_advance'
   }),date);
   report.worldWeeksVerified++;
   report.worldMatchesCommitted+=weeklyReceipt.matches_committed;
   report.checkpoints++;
  }
  if(quarterly(date)||date===endDate){
   await adapter.verifyWorldInvariants({date,days:report.days});
   report.quarterlyChecks++;
   const saveReceipt=await adapter.probeSaveReload({date,days:report.days});
   assertVerifiedCareerSaveReload(saveReceipt,date);
   if(await adapter.readCareerDate()!==date){
    throw Error('Save/reload changed the active career date on '+date);
   }
   report.saveLoadProbes++;
   onProgress({...report});
  }
 }
 // Real-game preconditions are necessary, but only all subsystem checks and the
 // final explicit world date may certify a full 2050 replay.
 await adapter.verifyWorldInvariants({date:endDate,days:report.days,final:true});
 if(await adapter.readCareerDate()!==endDate)throw Error('Final persisted career date mismatch');
 return {...report,status:'COMPLETED_WITH_ADAPTER_ASSERTIONS'};
 }finally{
  // Release even after a failed schema gate, interrupted match, or day drift.
  await adapter.releaseExclusiveReplayLease({leaseId:lease.leaseId});
 }
}
