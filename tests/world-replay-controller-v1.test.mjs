import test from 'node:test';
import assert from 'node:assert/strict';
import {replayIsolatedWorld,nextDay,isoDay} from '../qa/world-2050/replay-controller.mjs';

function makeWorld(startDate='2025-12-01'){
 let date=startDate, calls=0, checkpoints=0, matches=0, rolled=0, invariants=0, probes=0, leaseAcquires=0, leaseReleases=0;
 const checkpointed=new Set(), matchDone=new Set(), years=new Set();
 const world={
  async assertIsolatedEnvironment(){},
  async acquireExclusiveReplayLease(){leaseAcquires++;return {acquired:true,leaseId:'isolated-mock-exclusive'}},
  async releaseExclusiveReplayLease({leaseId}){assert.equal(leaseId,'isolated-mock-exclusive');leaseReleases++},
  async assertSchemaParity(){},
  async assertSeedReady(){},
  async readCareerDate(){return date},
  async advanceDay({expectedFromDate}){
   calls++;
   assert.equal(expectedFromDate,date);
   if(date==='2025-12-03'&&!matchDone.has(date)){
    return {ok:false,reason:'pending_match',due_matches:{matches:[{id:91}]}};
   }
   if(date.endsWith('-12-31')&&!years.has(Number(date.slice(0,4))+1)){
    return {ok:false,requires_rollover:true,new_year:Number(date.slice(0,4))+1};
   }
   if(new Date(date+'T00:00:00Z').getUTCDay()===0&&!checkpointed.has(date)){
    return {ok:false,checkpoint_required:true,checkpoint_date:date,from_date:date};
   }
   date=nextDay(date);
   return {ok:true,date,weekly_checkpoint_due:new Date(date+'T00:00:00Z').getUTCDay()===0,
      week_start_date:date};
  },
  async runWeeklyCheckpoint({checkpointDate}){
   checkpoints++;checkpointed.add(checkpointDate);
   // Explicit MOCK receipt: unit tests exercise only the controller protocol.
   // Live certification must reconstruct these numbers from actual DB match rows.
   return {
    ok:true,checkpoint_date:checkpointDate,world_run_id:'mock-world-'+checkpointDate,
    world_simulation_committed:true,checkpoint_persisted:true,ranking_integrity_ok:true,
    matches_due:0,matches_committed:0,managed_matches_pending:0,duplicate_match_effects:0
   };
  },
  async rolloverSeason({newYear}){rolled++;years.add(newYear)},
  async playManagedMatch({expectedFromDate}){matches++;matchDone.add(expectedFromDate)},
  async probeSaveReload(){
   probes++;
   // MOCK ONLY. Real stage adapter MUST verify a saved, independently
   // reloaded, full-state snapshot and exercise failed-load rollback.
   return {
    ok:true,date,slot_persisted:true,session_reopened:true,load_committed:true,
    failed_load_rollback_verified:true,snapshot_scope:'full_career',slot_id:'mock-slot-1',
    before_sha256:'a'.repeat(64),after_sha256:'a'.repeat(64),
    duplicate_daily_commits:0,duplicate_match_effects:0,duplicate_recovery_effects:0,
    date_skips:0,ranking_mismatches:0,career_state_mismatches:0
   };
  },
  async verifyWorldInvariants(){invariants++}
 };
 return {world,stats:()=>({date,calls,checkpoints,matches,rolled,invariants,probes,leaseAcquires,leaseReleases})};
}

test('ISO day utility rejects illegal dates, advances across leap years',()=>{
 assert.throws(()=>isoDay('2025-02-29'),/Invalid calendar/);
 assert.equal(nextDay('2028-02-28'),'2028-02-29');
 assert.equal(nextDay('2028-12-31'),'2029-01-01');
});

test('preflight blocks mutation when schema parity fails',async()=>{
 const {world,stats}=makeWorld();
 world.assertSchemaParity=()=>{throw Error('599 missing functions')};
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),/599 missing functions/);
 assert.equal(stats().calls,0);
});

test('daily replay must complete managed matches without skipping day or replaying match',async()=>{
 const {world,stats}=makeWorld();
 const r=await replayIsolatedWorld({adapter:world,endDate:'2025-12-06'});
 assert.equal(r.days,5);
 assert.equal(stats().date,'2025-12-06');
 assert.equal(r.managedMatches,1);
 assert.equal(stats().matches,1);
 assert.equal(r.status,'COMPLETED_WITH_ADAPTER_ASSERTIONS');
});

test('weekly checkpoint is committed once and season rollover is applied before new day',async()=>{
 const {world,stats}=makeWorld('2025-12-27');
 const r=await replayIsolatedWorld({adapter:world,startDate:'2025-12-27',endDate:'2026-01-03'});
 assert.equal(r.days,7);
 assert.equal(r.rollovers,1);
 assert.equal(r.checkpoints,1);
 assert.equal(stats().date,'2026-01-03');
});

test('repeated checkpoint is a hard error, not an endless loop',async()=>{
 const {world}=makeWorld('2025-12-28');
 world.runWeeklyCheckpoint=async({checkpointDate})=>({
  ok:true,checkpoint_date:checkpointDate,world_run_id:'mock-uncommitted-'+checkpointDate,
  world_simulation_committed:true,checkpoint_persisted:true,ranking_integrity_ok:true,
  matches_due:0,matches_committed:0,managed_matches_pending:0,duplicate_match_effects:0
 });
 // This intentionally does NOT mark checkpointed in the mock world; the
 // next attempt must reject the unresolved repeated weekly condition.
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,startDate:'2025-12-28',endDate:'2025-12-29'}),/Unresolved repeat/);
});

test('no Match Center adapter means no certification, never auto-select AI winner',async()=>{
 const {world}=makeWorld();
 delete world.playManagedMatch;
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-05'}),/Missing required real-world adapter: playManagedMatch/);
});

test('server must persist exactly the next date; never accept a double day',async()=>{
 const {world}=makeWorld();
 world.advanceDay=async()=>({ok:true,date:'2025-12-04'});
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-03'}),/Non-sequential day/);
});

test('simplified 2025-2050 adapter can test controller length but NEVER certify game world',async()=>{
 const {world,stats}=makeWorld('2025-12-01');
 const r=await replayIsolatedWorld({adapter:world,startDate:'2025-12-01',endDate:'2050-12-31'});
 assert.equal(r.days,9161);
 assert.equal(stats().date,'2050-12-31');
 assert.ok(r.quarterlyChecks>=100);
 assert.equal(r.status,'COMPLETED_WITH_ADAPTER_ASSERTIONS');
 assert.notEqual(r.status,'REAL_GAME_2050_CERTIFIED');
});

test('no exclusive shared lease means zero real-game day writes',async()=>{
 const {world,stats}=makeWorld();
 world.acquireExclusiveReplayLease=async()=>({acquired:false});
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),/Exclusive isolated replay lease unavailable/);
 assert.equal(stats().calls,0);
 assert.equal(stats().leaseReleases,0);
});

test('lease is always released if a 2025-2050 preflight fails after acquisition',async()=>{
 const {world,stats}=makeWorld();
 world.assertSchemaParity=async()=>{throw Error('Stage function parity drift')};
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),/Stage function parity drift/);
 assert.equal(stats().calls,0);
 assert.equal(stats().leaseAcquires,1);
 assert.equal(stats().leaseReleases,1);
});

test('lease is released after a real-game day rejects or jumps ahead',async()=>{
 const {world,stats}=makeWorld();
 world.advanceDay=async()=>{throw Error('Database statement_timeout after long world match')};
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),/statement_timeout/);
 assert.equal(stats().leaseAcquires,1);
 assert.equal(stats().leaseReleases,1);
});

test('exclusive lease refuses concurrent runs against the same world adapter',async()=>{
 let held=false,acquired=0,released=0;
 const world={...makeWorld().world};
 world.acquireExclusiveReplayLease=async()=>{
   if(held)return {acquired:false};
   held=true;acquired++;return {acquired:true,leaseId:'same-db-stage-world'};
 };
 world.releaseExclusiveReplayLease=async({leaseId})=>{
   assert.equal(leaseId,'same-db-stage-world');
   held=false;released++;
 };
 const results=await Promise.allSettled([
   replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
   replayIsolatedWorld({adapter:world,endDate:'2025-12-04'})
 ]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(results.filter(r=>r.status==='rejected').length,1);
 assert.match(results.find(r=>r.status==='rejected').reason.message,/Exclusive isolated replay lease unavailable/);
 assert.equal(acquired,1);
 assert.equal(released,1);
 assert.equal(held,false);
});

test('25-year controller smoke includes all rollovers and a released lease, not game certification',async()=>{
 const {world,stats}=makeWorld('2025-12-01');
 const r=await replayIsolatedWorld({adapter:world,startDate:'2025-12-01',endDate:'2050-12-31'});
 assert.equal(r.days,9161);
 assert.equal(r.rollovers,25);
 assert.ok(r.checkpoints>=1300);
 assert.ok(r.saveLoadProbes>=100);
 assert.equal(stats().leaseAcquires,1);
 assert.equal(stats().leaseReleases,1);
 assert.notEqual(r.status,'REAL_GAME_2050_CERTIFIED');
});

test('real-week adapter cannot pass off a bare clock marker as world simulation',async()=>{
 const {world}=makeWorld('2025-12-27');
 world.runWeeklyCheckpoint=async()=>({ok:true,checkpoint_date:'2025-12-28'});
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,startDate:'2025-12-27',endDate:'2025-12-29'}),
   /World week lacks verified simulation/);
});

test('weekly world results must reconcile every due AI and managed match',async()=>{
 const {world}=makeWorld('2025-12-27');
 world.runWeeklyCheckpoint=async({checkpointDate})=>({
  ok:true,checkpoint_date:checkpointDate,world_run_id:'mock-world-'+checkpointDate,
  world_simulation_committed:true,checkpoint_persisted:true,ranking_integrity_ok:true,
  matches_due:9,matches_committed:5,managed_matches_pending:1,duplicate_match_effects:0
 });
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,startDate:'2025-12-27',endDate:'2025-12-29'}),
   /World week has missing or duplicated match effects/);
});

test('weekly checkpoint refuses duplicated match effects even when its own flag is green',async()=>{
 const {world}=makeWorld('2025-12-27');
 world.runWeeklyCheckpoint=async({checkpointDate})=>({
  ok:true,checkpoint_date:checkpointDate,world_run_id:'mock-world-'+checkpointDate,
  world_simulation_committed:true,checkpoint_persisted:true,ranking_integrity_ok:true,
  matches_due:9,matches_committed:9,managed_matches_pending:0,duplicate_match_effects:1
 });
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,startDate:'2025-12-27',endDate:'2025-12-29'}),
   /World week has missing or duplicated match effects/);
});

test('verified weekly receipts accumulate genuine world match counts without leap in dates',async()=>{
 const {world}=makeWorld('2025-12-27');
 const commitCheckpoint=world.runWeeklyCheckpoint.bind(world);
 world.runWeeklyCheckpoint=async({checkpointDate,...args})=>{
  // Preserve the mock's actual weekly state transition before adding a
  // positive receipt: otherwise the next day legitimately detects a loop.
  const committed=await commitCheckpoint({checkpointDate,...args});
  return {...committed,matches_due:12,matches_committed:12};
 };
 const result=await replayIsolatedWorld({adapter:world,startDate:'2025-12-27',endDate:'2026-01-03'});
 assert.equal(result.checkpoints,1);
 assert.equal(result.worldWeeksVerified,1);
 assert.equal(result.worldMatchesCommitted,12);
 assert.equal(result.lastCommittedDate,'2026-01-03');
 assert.notEqual(result.status,'REAL_GAME_2050_CERTIFIED');
});

test('save/load cannot pass with bare or missing response',async()=>{
 const {world}=makeWorld();
 world.probeSaveReload=async()=>undefined;
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
  /Save\/reload lacks persisted full-state/);
});

test('persisted save/load demands identical SHA256 of entire career before and after',async()=>{
 const {world,stats}=makeWorld();
 const original=world.probeSaveReload;
 world.probeSaveReload=async()=>({...await original(),after_sha256:'b'.repeat(64)});
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
  /Save\/reload lacks persisted full-state/);
 assert.equal(stats().leaseReleases,1);
});

test('failed-load rollback is mandatory, not an optional success badge',async()=>{
 const {world}=makeWorld();
 const original=world.probeSaveReload;
 world.probeSaveReload=async()=>({...await original(),failed_load_rollback_verified:false});
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
  /Save\/reload lacks persisted full-state/);
});

test('save/load detects duplicate match, fatigue, daily and ranking effects',async()=>{
 for(const key of ['duplicate_daily_commits','duplicate_match_effects','duplicate_recovery_effects','date_skips','ranking_mismatches','career_state_mismatches']){
  const {world}=makeWorld();
  const original=world.probeSaveReload;
  world.probeSaveReload=async()=>({...await original(),[key]:1});
  await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
   /Save\/reload changed or duplicated career state/);
 }
});

test('a reloaded date that moves must fail even when checksum receipt is forged',async()=>{
 const {world}=makeWorld();
 const original=world.probeSaveReload;
 let fakeDate='2025-12-01';
 world.probeSaveReload=async()=>{
  const receipt=await original();
  fakeDate='2025-12-05';
  return receipt;
 };
 const actualReader=world.readCareerDate;
 world.readCareerDate=async()=>fakeDate==='2025-12-05'?fakeDate:actualReader();
 await assert.rejects(()=>replayIsolatedWorld({adapter:world,endDate:'2025-12-04'}),
  /Save\/reload changed the active career date/);
});

test('offline multi-season replay requires a valid save/load receipt each quarter',async()=>{
 const {world,stats}=makeWorld();
 const outcome=await replayIsolatedWorld({adapter:world,endDate:'2028-01-01'});
 assert.ok(outcome.saveLoadProbes>=8);
 assert.equal(outcome.saveLoadProbes,stats().probes);
 assert.equal(outcome.lastCommittedDate,'2028-01-01');
 assert.notEqual(outcome.status,'REAL_GAME_2050_CERTIFIED');
});
