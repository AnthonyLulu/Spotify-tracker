import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

/**
 * P0 fault-injection harness. It executes the actual production HTTP branches
 * against an in-memory, isolated database stub. No calls to the live server and
 * no user saves are mutated. Production TypeScript casts are erased for Node.
 */
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const start=edge.indexOf('if(path.endsWith("/api/load-slot")');
const end=edge.indexOf('if(path.endsWith("/api/delete-slot")',start);
const recoverStart=edge.indexOf('// Durable crash recovery for interrupted loads.');
const recoverEnd=edge.indexOf('if((\n    path.endsWith("/api/refresh-live-rankings")',recoverStart);
assert.ok(start>=0&&end>start&&recoverStart>=0&&recoverEnd>recoverStart);
const stripTs=s=>s.replace(/\b(let|const) (\w+):any\b/g,'$1 $2').replace(/ as any\b/g,'');
const loadCode=stripTs(edge.slice(start,end));
const recoveryCode=stripTs(edge.slice(recoverStart,recoverEnd));
const copy=x=>x===undefined?undefined:JSON.parse(JSON.stringify(x));

function harness(mode='normal'){
  const state={
    world:{day:'2025-12-02',matches:[{id:7,score:'6-4 6-4'}],fatigue:[{player:51,debt:17}],ranking:[{player:51,rank:2}],events:[{type:'original'}]},
    legacy:{id:'isolated-test-key',payload:{day:'2025-12-02',liveMatch:{score:'3-3'}},updated_at:'2025-12-02T00:00:00Z'},
    journal:null,
    firstRestore:true,
    alteredDuringVerify:false,
    operations:[]
  };
  const initial=copy({world:state.world,legacy:state.legacy});
  const slot={
    id:1,slot_no:1,slot_name:'Snapshot essai',career_date:'2025-12-01',week:1,
    snapshot_scope:'managed_timeline_live_v8',
    managed_snapshot:{world:{day:'2025-12-01',matches:[],fatigue:[],ranking:[{player:51,rank:2}],events:[]}},
    local_payload:{day:'2025-12-01',liveMatch:{score:'4-4'},liveAuto:true}
  };
  const db={
    from(table){
      const q={
        select(){return q;},
        eq(){return q;},
        async maybeSingle(){
          if(table==='game_save_slots')return {data:copy(slot),error:null};
          if(table==='game_saves')return {data:copy(state.legacy),error:null};
          throw Error('Unexpected select '+table);
        },
        async upsert(data){
          state.operations.push('upsert:'+table);
          if(table!=='game_saves')throw Error('Unexpected upsert '+table);
          if(mode==='legacy_fail'&&data.payload?.day==='2025-12-01')
            return {error:{message:'simulated legacy write failure'}};
          state.legacy=copy(data);return {error:null};
        },
        delete(){return {eq:async()=>{state.legacy=null;return {error:null}}}},
        async insert(data){
          state.operations.push('insert:'+table);
          if(mode==='event_fail')return {error:{message:'simulated journal timeout'}};
          state.world.events.push(copy(data));return {error:null};
        }
      };
      return q;
    },
    async rpc(name,args={}){
      state.operations.push('rpc:'+name);
      if(name==='cb_prepare_load_recovery_v33'){
        state.journal={
          operation_id:'op-test',status:'prepared',
          safety_snapshot:copy(args.p_safety_snapshot),
          safety_digest:args.p_safety_digest,
          legacy_present:args.p_legacy_present,
          legacy_snapshot:copy(args.p_legacy_snapshot),
          legacy_digest:args.p_legacy_digest
        };
        return {data:'op-test'};
      }
      if(name==='cb_mark_load_recovery_v33'){
        if(state.journal)state.journal.status=args.p_status;
        return {data:true};
      }
      if(name==='cb_get_load_recovery_v33')return {data:copy(state.journal)};
      if(name==='cb_clear_load_recovery_v33'){state.journal=null;return {data:true}};
      if(name==='cb_acquire_write_lock_v31')return {data:'safe-lease'};
      if(name==='cb_touch_write_lock_v31')return {data:true};
      throw Error('Unexpected RPC: '+name);
    }
  };
  const ctx={
    db,state,path:'/api/load-slot',req:{method:'POST',json:async()=>({slot_no:1})},
    AGE_REFERENCE_DATE:'2025-12-01',n:(v)=>Number(v),saveId:()=> 'isolated-test-key',
    captureManagedSaveSnapshot:async()=>{
      const world=copy(state.world);
      if(mode==='digest_mismatch'&&state.firstRestore===false&&world.day==='2025-12-02'){
        world.matches.push({id:999,score:'unexpected'});
      }
      return {world};
    },
    captureLiveCheckpointSnapshot:async x=>copy(x),
    snapshotRollbackDigest:async x=>JSON.stringify(x),
    canonicalSnapshotValue:x=>x,
    sha256Hex:async x=>x,
    restoreManagedSaveSnapshot:async snap=>{
      state.world=copy(snap.world);
      const first=state.firstRestore;state.firstRestore=false;
      if(mode==='restore_partial_fail'&&first){
        state.world.fatigue.push({player:51,debt:99});
        throw Error('simulated partial restore crash');
      }
      return {restored:true};
    },
    h:(body,status=200)=>({body,status}),
    setInterval:()=>42,console
  };
  return {state,initial,ctx};
}

async function invokeLoad(mode){
  const h=harness(mode);
  const out=await vm.runInNewContext('(async()=>{'+loadCode+'})()',h.ctx);
  return {...h,out};
}

for(const mode of ['legacy_fail','event_fail','restore_partial_fail']){
  test('failed load recovers EXACT state: '+mode,async()=>{
    const {state,initial,out}=await invokeLoad(mode);
    assert.equal(out.status,409);
    assert.equal(out.body.rollback_recovered,true);
    assert.equal(out.body.rollback_verified,true);
    assert.equal(out.body.rollback_durable,true);
    assert.deepEqual(copy({world:state.world,legacy:state.legacy}),initial);
    assert.equal(state.journal,null);
  });
}

test('digest mismatch does not falsely declare a successful rollback',async()=>{
  const {state,out}=await invokeLoad('digest_mismatch');
  assert.equal(out.status,409);
  assert.equal(out.body.rollback_recovered,false);
  assert.equal(out.body.rollback_verified,false);
  assert.ok(out.body.rollback_error?.includes('mismatch'));
  assert.equal(state.journal?.status,'rollback_pending');
});

test('successful load clears live-match leftovers and durable safety journal',async()=>{
  const {state,out}=await invokeLoad('normal');
  assert.equal(out.status,200);
  assert.equal(out.body.ok,true);
  assert.equal(out.body.rollback_durable,true);
  assert.equal(state.journal,null);
  assert.equal(state.world.day,'2025-12-01');
  assert.equal(out.body.local_payload.liveMatch,undefined);
  assert.equal(out.body.local_payload.liveAuto,undefined);
});

test('process-death recovery restores the original world and legacy mirror',async()=>{
  const h=harness();
  const safety={world:copy(h.state.world)};
  h.state.journal={
    operation_id:'op-crashed',status:'applying',
    safety_snapshot:safety,safety_digest:JSON.stringify(safety),
    legacy_present:true,legacy_snapshot:copy(h.state.legacy),
    legacy_digest:JSON.stringify(h.state.legacy)
  };
  h.state.world.day='2028-06-20';
  h.state.world.matches.push({id:500,score:'ghost match'});
  h.state.legacy.payload.day='2028-06-20';
  h.ctx.writeLockToken=null;
  h.ctx.writeLockHeartbeat=null;
  const response=await vm.runInNewContext('(async()=>{'+recoveryCode+'})()',h.ctx);
  assert.equal(response,undefined);
  assert.deepEqual(copy({world:h.state.world,legacy:h.state.legacy}),h.initial);
  assert.equal(h.state.journal,null);
});

test('failed crash-recovery digest keeps pending journal and blocks reads',async()=>{
  const h=harness('digest_mismatch');
  const safety={world:copy(h.state.world)};
  h.state.journal={
    operation_id:'op-crashed',status:'applying',
    safety_snapshot:safety,safety_digest:'intentionally-bad-digest',
    legacy_present:true,legacy_snapshot:copy(h.state.legacy),
    legacy_digest:JSON.stringify(h.state.legacy)
  };
  h.ctx.writeLockToken=null;
  h.ctx.writeLockHeartbeat=null;
  const response=await vm.runInNewContext('(async()=>{'+recoveryCode+'})()',h.ctx);
  assert.equal(response.status,503);
  assert.equal(response.body.recovery_pending,true);
  assert.equal(h.state.journal?.status,'rollback_pending');
});
