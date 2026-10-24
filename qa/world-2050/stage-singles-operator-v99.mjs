#!/usr/bin/env node
// Manual, stage-only Court Boss world-singles operator.
// Default = read-only. --execute authorizes at most two tournament steps
// (four absolute max) and never schedules itself. 2026 singles only.
import {pathToFileURL} from 'node:url';
import {advanceIsolatedSinglesWeeks} from './resumable-singles-weeks-v85.mjs';
import {isoDay} from './replay-controller.mjs';
import {assertDirectStageUrl,createStagePsqlAdapter} from './stage-psql-adapter-v99.mjs';

function nextWeek(date){
 const d=isoDay(date);d.setUTCDate(d.getUTCDate()+7);return d.toISOString().slice(0,10);
}
export function parseWeekOptions(args){
 const o={execute:false,maxSteps:2};
 for(const arg of args){
  if(arg==='--execute')o.execute=true;
  else if(arg.startsWith('--from='))o.fromDate=arg.slice(7);
  else if(arg.startsWith('--to='))o.toDate=arg.slice(5);
  else if(arg.startsWith('--max-steps=')){
   const n=arg.slice(12);
   if(!/^[1-4]$/.test(n))throw Error('World stage budget must be 1 to 4 steps');
   o.maxSteps=Number(n);
  }else throw Error('Unknown world stage option');
 }
 if(!o.fromDate||!o.toDate)throw Error('Explicit --from and --to are required');
 const start=isoDay(o.fromDate),end=isoDay(o.toDate);
 if(start.getUTCDay()!==0||end.getUTCDay()!==0
   ||o.fromDate<'2026-01-04'||o.toDate>'2026-12-31'
   ||nextWeek(o.fromDate)!==o.toDate){
  throw Error('Exactly one Sunday-to-Sunday 2026 stage week is required');
 }
 return o;
}

export async function operateStageSinglesWeek({adapter,options}){
 if(!adapter||typeof adapter.assertStageIsolated!=='function')
  throw Error('A real isolated stage adapter is required');
 const preflight=await adapter.assertStageIsolated();
 if(preflight?.ok!==true||preflight.environment!=='isolated_staging'
   ||preflight.user_saves!==0||preflight.active_careers!==0)
  throw Error('Stage preflight failed: no world steps authorized');
 const key='WORLD-SINGLES:'+options.fromDate+':'+options.toDate;
 const current=await adapter.getWeekStatus({key});
 if(!options.execute){
  return {status:'DRY_RUN_NO_WRITES',scope:'world_singles_only',
   key,existing_job:current?.status??null,
   events_expected:current?.expected_items??null,
   events_done:current?.completed_items??null,
   may_certify_2050:false};
 }
 // The v85 controller checks every persisted state after each event. A busy
 // response, interrupted transaction or inconsistent result stops this call.
 const result=await advanceIsolatedSinglesWeeks({
  adapter,fromDate:options.fromDate,throughDate:options.toDate,
  maxSteps:options.maxSteps,maxWeeks:1
 });
 return {...result,may_certify_2050:false};
}

const isMain=process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href;
if(isMain){
 try{
  if(process.argv.includes('--help')){
   console.log('Usage: CB_E2E_DB_URL=<secret-direct-stage-DSN> node qa/world-2050/stage-singles-operator-v99.mjs --from=2026-03-08 --to=2026-03-15 [--max-steps=2] [--execute]');
  }else{
   const options=parseWeekOptions(process.argv.slice(2));
   assertDirectStageUrl(process.env.CB_E2E_DB_URL);
   const adapter=createStagePsqlAdapter({dsn:process.env.CB_E2E_DB_URL});
   console.log(JSON.stringify(await operateStageSinglesWeek({adapter,options})));
  }
 }catch(error){
  // No secret contents or raw SQL are emitted to stdout or logs.
  console.error('World stage operator stopped:',error.message);
  process.exitCode=1;
 }
}
