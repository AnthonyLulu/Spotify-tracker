import test from 'node:test';
import assert from 'node:assert/strict';
import {buildCountryNamePools,planSynthetic2025Adults} from '../qa/world-2050/synthetic-adult-planner.mjs';

const letters=n=>{let s='';do{s=String.fromCharCode(65+n%26)+s;n=Math.floor(n/26)-1}while(n>=0);return s};
const makeRows=(countries=1,first=12,last=16,uniqueCountry=true)=>{
 const rows=[];
 for(let ci=0;ci<countries;ci++){
  const country='A'+letters(Math.floor(ci/26)).padStart(1,'A')+letters(ci%26);
  const prefix=uniqueCountry?country:'SHARED';
  for(let j=0;j<first;j++)rows.push({country,kind:'first',value:'First'+prefix+letters(j),license:'CC0'});
  for(let j=0;j<last;j++)rows.push({country,kind:'last',value:'Last'+prefix+letters(j),license:'MIT'});
 }
 return rows;
};

test('country pools use only licensed first/last entries with enough local diversity',()=>{
 const rows=makeRows();
 rows.push({country:'AAA',kind:'first',value:'Fake',license:'Proprietary'});
 rows.push({country:'USA',kind:'last',value:'123',license:'CC0'});
 assert.equal(buildCountryNamePools(rows).length,1);
 assert.equal(buildCountryNamePools(rows)[0].capacity,192);
});

test('seed is deterministic, unique, synthetic, and has complete 2025 birth-year values',()=>{
 const args={licensedNames:makeRows(2,20,20),existingAdults:23950,targetAdults:24000,
  existingNames:['FirstAAAa LastAAAa']};
 const a=planSynthetic2025Adults(args),b=planSynthetic2025Adults(args);
 assert.deepEqual(a,b);
 assert.equal(a.status,'PLAN_ONLY_NO_DB_WRITE');
 assert.equal(a.plannedAdditions,50);
 assert.equal(a.finalAdults,24000);
 assert.equal(new Set(a.players.map(p=>p.name_norm)).size,50);
 assert.ok(a.players.every(p=>p.is_real===false&&p.game_generated===true&&p.career_status==='active'));
 assert.ok(a.players.every(p=>p.data_snapshot==='2025-12-01'&&p.birth_date.startsWith(String(2025-p.age))));
 assert.ok(a.players.every(p=>p.ranking===null&&p.points===0));
});

test('realistic full 21,110 adult shortfall is plan-able offline without database writes',()=>{
 const rows=makeRows(25,35,45);
 const result=planSynthetic2025Adults({licensedNames:rows,existingAdults:2890,targetAdults:24000});
 assert.equal(result.plannedAdditions,21110);
 assert.equal(result.finalAdults,24000);
 assert.equal(result.eligibleCountries,25);
 assert.equal(new Set(result.players.map(x=>x.name_norm)).size,21110);
 assert.ok(result.players.some(x=>x.career_focus==='doubles'));
});

test('same names across countries fail closed when global combinations are exhausted',()=>{
 assert.throws(()=>planSynthetic2025Adults({
  licensedNames:makeRows(2,8,8,false),existingAdults:23920,targetAdults:24000
 }),/Exhausted globally unique/);
});

test('invalid baseline, quota, and missing pool all fail before generating identities',()=>{
 assert.throws(()=>planSynthetic2025Adults({licensedNames:[],existingAdults:21000}),/No eligible licensed/);
 assert.throws(()=>planSynthetic2025Adults({licensedNames:[],existingAdults:0,maxAdditions:100}),/safety cap/);
 assert.throws(()=>planSynthetic2025Adults({licensedNames:[],existingAdults:-1}),/Invalid adult baseline/);
 assert.throws(()=>planSynthetic2025Adults({licensedNames:[],existingAdults:24000,targetAdults:23000}),/Invalid adult target/);
});

test('existing real-name collisions are reserved, not reissued',()=>{
 const rows=makeRows();
 const first=planSynthetic2025Adults({licensedNames:rows,existingAdults:23999,targetAdults:24000});
 const second=planSynthetic2025Adults({licensedNames:rows,existingAdults:23999,targetAdults:24000,existingNames:[first.players[0].name]});
 assert.notEqual(first.players[0].name_norm,second.players[0].name_norm);
});
