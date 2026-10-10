import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const js=fs.readFileSync(new URL('../court-boss/atp-net-forecast-v57.js',import.meta.url),'utf8');
const modules=fs.readFileSync(new URL('../court-boss/modules.js',import.meta.url),'utf8');
const html=fs.readFileSync(new URL('../court-boss/index.html',import.meta.url),'utf8');
const play=fs.readFileSync(new URL('../court-boss/play.html',import.meta.url),'utf8');
const ctx=vm.createContext({Date,Number,String,Set,Math});
vm.runInContext(js,ctx);
const evaluate=(ledger,to)=>vm.runInContext('cbAtpNetForecast(input,to)',Object.assign(ctx,{input:ledger,to}));
const item=(key,points,drop='2026-10-01',rank_category='ATP250',earned_date='2025-10-01')=>({
 event_key:key,points,drop_date:drop,rank_category,earned_date,counting:true,estimated:false
});
const opt17=()=>Array.from({length:17},(_,i)=>item('optional-'+i,200));
const big=item('500-final',330,'2026-03-02','ATP500','2025-03-02');
const reserve=item('reserve',100);

test('date helpers are UTC deterministic and reject illegal calendar days',()=>{
 assert.equal(vm.runInContext("cbAtpDayAfter('2028-02-28')",ctx),'2028-02-29');
 assert.equal(vm.runInContext("cbAtpDayAfter('2026-03-08')",ctx),'2026-03-09');
 assert.equal(vm.runInContext("cbAtpDayAfter('2026-02-30')",ctx),null);
});

test('ATP500 330 expires without replacement: net loss -330',()=>{
 const ledger={date:'2026-03-01',total:330,counting:[big],non_counting:[]};
 const r=evaluate(ledger,'2026-03-09');
 assert.equal(r.ok,true);
 assert.equal(r.points_before,330);
 assert.equal(r.points_after,0);
 assert.equal(r.expired_counted_points,330);
 assert.equal(r.net_change_points,-330);
 assert.equal(r.other_effects_points,0);
});

test('ATP500 330 expires and reserve 100 enters the 18th slot: net loss -230',()=>{
 const ledger={date:'2026-03-01',total:3730,counting:[big,...opt17()],non_counting:[reserve]};
 const r=evaluate(ledger,'2026-03-09');
 assert.equal(r.ok,true);
 assert.equal(r.points_before,3730);
 assert.equal(r.points_after,3500);
 assert.equal(r.expired_counted_points,330);
 assert.equal(r.net_change_points,-230);
 assert.equal(r.other_effects_points,100);
});

test('mandatory Grand Slam expiration still permits an unused optional score',()=>{
 const slam=item('slam',2000,'2026-03-02','Grand Slam','2025-03-02');
 const ledger={date:'2026-03-01',total:5400,counting:[slam,...opt17()],non_counting:[reserve]};
 const r=evaluate(ledger,'2026-03-09');
 assert.equal(r.ok,true);
 assert.equal(r.expired_counted_points,2000);
 assert.equal(r.net_change_points,-1900);
 assert.equal(r.other_effects_points,100);
});

test('refuse an uncalibrated or incomplete ledger instead of inventing a net move',()=>{
 const bad=evaluate({date:'2026-03-01',total:999,counting:[big],non_counting:[]},'2026-03-09');
 assert.equal(bad.ok,false);assert.equal(bad.reason,'not_calibrated');
 const dup=evaluate({date:'2026-03-01',total:660,counting:[big,big],non_counting:[]},'2026-03-09');
 assert.equal(dup.ok,false);assert.equal(dup.reason,'incomplete_or_duplicate_event');
 const empty=evaluate({date:'2026-03-01',total:0,counting:[],non_counting:[]},'2026-03-01');
 assert.equal(empty.ok,false);
});

test('mobile screens show optional gross-to-net projection with explicit assumptions',()=>{
 assert.match(modules,/cbAtpNetForecast\(ledger,cbAtpDayAfter\(nextDefense\.week_end\)\)/);
 assert.match(modules,/Projection ATP à résultats constants/);
 assert.match(modules,/Hypothèse : aucun nouveau résultat/);
 assert.match(modules,/Projection nette momentanément indisponible/);
 for(const src of [html,play]){
   const first=src.indexOf('atp-net-forecast-v57.js'),second=src.indexOf('modules.js');
   assert.ok(first>=0&&second>first);
 }
 assert.doesNotMatch(js,/\bfetch\s*\(|XMLHttpRequest|localStorage/);
});
