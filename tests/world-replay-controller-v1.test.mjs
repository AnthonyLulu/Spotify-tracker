import test from 'node:test';
import assert from 'node:assert/strict';
import {replayIsolatedWorld,nextDay,isoDay} from '../qa/world-2050/replay-controller.mjs';

function makeWorld(startDate='2025-12-01'){
 let date=startDate, calls=0, checkpoints=0, matches=0, rolled=0, invariants=0, probes=0;
 const checkpointed=new Set(), matchDone=new Set(), years=new Set();
 const world={
  async assertIsolatedEnvironment(){},
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
  async runWeeklyCheckpoint({checkpointDate}){checkpoints++;checkpointed.add(checkpointDate)},
  async rolloverSeason({newYear}){rolled++;years.add(newYear)},
  async playManagedMatch({expectedFromDate}){matches++;matchDone.add(expectedFromDate)},
  async probeSaveReload(){probes++},
  async verifyWorldInvariants(){invariants++}
 };
 return {world,stats:()=>({date,calls,checkpoints,matches,rolled,invariants,probes})};
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
 world.runWeeklyCheckpoint=async()=>{};
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
