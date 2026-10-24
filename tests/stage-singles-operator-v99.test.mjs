import test from 'node:test';
import assert from 'node:assert/strict';
import {parseWeekOptions,operateStageSinglesWeek} from '../qa/world-2050/stage-singles-operator-v99.mjs';
import {assertDirectStageUrl,createStagePsqlAdapter} from '../qa/world-2050/stage-psql-adapter-v99.mjs';

const testDsn='postgresql://test-user:test-password@db.sozrygjxjotozrsenred.supabase.co:5432/postgres?sslmode=require';
const key='WORLD-SINGLES:2026-03-08:2026-03-15';
const opts={fromDate:'2026-03-08',toDate:'2026-03-15',maxSteps:2,execute:true};

test('deny production, other hosts, blank or non-SSL database URLs',()=>{
  assert.equal(assertDirectStageUrl(testDsn),testDsn);
  for(const url of ['postgresql://user:pass@db.qrsvliliezbiedmaewml.supabase.co/postgres',
    'postgresql://user:pass@evil.test/postgres',
    'postgresql://user:pass@db.sozrygjxjotozrsenred.supabase.co/postgres?sslmode=disable',
    'postgresql://user:pass@db.sozrygjxjotozrsenred.supabase.co/postgres?sslmode=prefer',
    'postgresql://db.sozrygjxjotozrsenred.supabase.co/postgres',
    '']){
    assert.throws(()=>assertDirectStageUrl(url));
  }
});
test('manual CLI requires a single 2026 Sunday week and explicit execute flag',()=>{
  const a=parseWeekOptions(['--from=2026-03-08','--to=2026-03-15']);
  assert.deepEqual(a,{execute:false,maxSteps:2,fromDate:'2026-03-08',toDate:'2026-03-15'});
  assert.equal(parseWeekOptions(['--from=2026-03-08','--to=2026-03-15','--execute']).execute,true);
  for(const args of [
    ['--from=2026-03-09','--to=2026-03-15'],
    ['--from=2026-03-08','--to=2050-03-15'],
    ['--from=2026-03-08','--to=2026-03-22'],
    ['--from=2026-03-08','--to=2026-03-15','--max-steps=5'],
    ['--from=2026-03-08','--to=2026-03-15','--force-prod']
  ])assert.throws(()=>parseWeekOptions(args));
});
test('stage adapter restricts statements and rejects arbitrary injected keys',async()=>{
 const seen=[];
 const a=createStagePsqlAdapter({dsn:testDsn,query:({sql})=>{
  seen.push(sql);
  if(sql.includes('to_regclass'))return {ok:true,environment:'isolated_staging',user_saves:0,active_careers:0};
  if(sql.includes('world_week_jobs_v1 j'))return null;
  return {ok:true,job_key:key,expected:19};
 }});
 assert.equal((await a.assertStageIsolated()).ok,true);
 assert.equal(await a.getWeekStatus({key}),null);
 await assert.rejects(()=>a.stepWeek({key:key+"';DROP TABLE public.players;--"}),/Invalid 2026/);
 await assert.rejects(()=>a.beginWeek({key,fromDate:'2026-03-08',toDate:'2026-03-22'}),/mismatch/);
 const r=await a.beginWeek({key,fromDate:'2026-03-08',toDate:'2026-03-15'});
 assert.equal(r.expected,19);
 assert.ok(seen.every(s=>!s.includes('DROP TABLE')));
});
function fakeStage({busy=false,saves=0}={}){
 const state={completed:1,status:'running',calls:0,begin:0,reads:0};
 const adapter={
  async assertStageIsolated(){return {ok:saves===0,environment:'isolated_staging',user_saves:saves,active_careers:0}},
  async getWeekStatus(){state.reads++;return {job_key:key,status:state.status,expected_items:19,completed_items:state.completed}},
  async beginWeek(){state.begin++;throw Error('Existing week must not be recreated')},
  async stepWeek(){
   state.calls++;
   if(busy)return {ok:false,retryable:true,reason:'busy'};
   state.completed++;
   return {ok:true,completed:state.completed,done:false};
  },
  async readWeekReceipt(){throw Error('An unfinished week may not get a strict receipt')}
 };
 return {state,adapter};
}
test('default inspection never starts or progresses a real week',async()=>{
 const f=fakeStage();
 const result=await operateStageSinglesWeek({adapter:f.adapter,options:{...opts,execute:false}});
 assert.equal(result.status,'DRY_RUN_NO_WRITES');
 assert.equal(result.events_done,1);
 assert.equal(f.state.calls,0);
 assert.equal(f.state.begin,0);
});
test('two-step budget makes bounded progress, with resumable persistence',async()=>{
 const f=fakeStage();
 const result=await operateStageSinglesWeek({adapter:f.adapter,options:opts});
 assert.equal(result.status,'PAUSED_NOT_2050_CERTIFIED');
 assert.equal(result.serverSteps,2);
 assert.equal(result.pendingItems,16);
 assert.equal(f.state.completed,3);
 assert.equal(f.state.calls,2);
 assert.equal(f.state.begin,0);
 assert.equal(result.may_certify_2050,false);
});
test('busy and user saves stop without retries or writes',async()=>{
 const busy=fakeStage({busy:true});
 const blocked=await operateStageSinglesWeek({adapter:busy.adapter,options:opts});
 assert.equal(blocked.status,'BLOCKED_BUSY_NOT_CERTIFIED');
 assert.equal(busy.state.completed,1);
 assert.equal(busy.state.calls,1);
 const saved=fakeStage({saves:1});
 await assert.rejects(()=>operateStageSinglesWeek({adapter:saved.adapter,options:opts}),/preflight failed/i);
 assert.equal(saved.state.calls,0);
});
test('ambiguous server failures abort rather than blindly replay',async()=>{
 const f=fakeStage();
 f.adapter.stepWeek=async()=>{f.state.calls++;throw Error('network outcome ambiguous')};
 await assert.rejects(()=>operateStageSinglesWeek({adapter:f.adapter,options:opts}),/outcome ambiguous/);
 assert.equal(f.state.calls,1);
 assert.equal(f.state.completed,1);
});
