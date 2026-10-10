import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const src=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const getPart=(start,end)=>{
 const i=src.indexOf(start);
 const j=src.indexOf(end,i);
 assert.ok(i>=0&&j>i,'required source functions must exist');
 return src.slice(i,j);
};
const nav=getPart('window.nav=async r=>{','\nasync function syncLegacySinglesEntries');
const loader=getPart('async function loadPlayerDatabase(){','\nasync function loadHistory(){');
const players=getPart('function playersPage(){','\nfunction staffFormerLabel(');

test('Players route renders without awaiting optional bootstrap or country catalog',()=>{
 assert.match(nav,/['"]match['"],['"]contracts['"]\]\.includes\(r\)/);
 assert.doesNotMatch(nav,/['"]match['"],['"]players['"],['"]contracts['"]/);
 assert.match(nav,/if\(r==='players'&&!countryRows\.length\)\{[\s\S]*?void loadCountries\(\)\.then/);
 assert.doesNotMatch(nav,/if\(r==='players'&&!countryRows\.length\)await/);
});

test('Player database starts at most once automatically; failed fetch is visible and explicitly retryable',()=>{
 assert.match(players,/if\(!dbAttempted&&!dbLoading\)/);
 assert.match(players,/dbAttempted=true/);
 assert.match(players,/dbError\?\`<div class="notice bad" role="alert">/);
 assert.match(players,/retryPlayerDatabase\(\)/);
 assert.match(src,/window\.retryPlayerDatabase=async/);
 assert.match(players,/dbLoaded&&!dbLoading&&!dbRows\.length/);
 assert.match(src,/dbAttempted=false;dbError='';/);
});

function harness(fetchData){
 return new Function('get',`
   let dbRows=[],dbCount=0,dbOffset=0,dbQuery='',dbCountry='',dbCircuit='Tous réels',
       dbLoaded=false,dbLoading=false,dbAttempted=false,dbError='';
   ${loader}
   return {loadPlayerDatabase,state:()=>({dbRows,dbCount,dbLoaded,dbLoading,dbAttempted,dbError})};
 `)(fetchData);
}

test('Failed player request does not forge zero players or enter a retry loop',async()=>{
 let hits=0;
 const x=harness(async()=>{hits++;throw new Error('500 timeout on players query')});
 await x.loadPlayerDatabase();
 assert.equal(hits,1);
 assert.equal(x.state().dbAttempted,true);
 assert.equal(x.state().dbLoading,false);
 assert.equal(x.state().dbLoaded,false);
 assert.match(x.state().dbError,/500 timeout/);
});

test('An explicit retry can recover full database results',async()=>{
 let hits=0;
 const x=harness(async()=>{
  hits++;
  if(hits===1)throw new Error('temporary backend failure');
  return {rows:[{id:120,name:'Test Player'}],count:321};
 });
 await x.loadPlayerDatabase();
 assert.match(x.state().dbError,/temporary backend failure/);
 await x.loadPlayerDatabase();
 assert.equal(hits,2);
 assert.equal(x.state().dbLoaded,true);
 assert.equal(x.state().dbError,'');
 assert.equal(x.state().dbCount,321);
 assert.equal(x.state().dbRows[0].id,120);
});
