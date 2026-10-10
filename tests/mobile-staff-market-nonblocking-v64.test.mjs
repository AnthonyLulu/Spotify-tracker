import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const begin=source.indexOf('window.nav=async r=>{');
const end=source.indexOf('\nasync function syncLegacySinglesEntries',begin);
assert.ok(begin>=0&&end>begin);
const navSource=source.slice(begin,end);

test('Staff global market loads after immediate managed-team render, never blocking route',async()=>{
 assert.match(navSource,/if\(r==='staff'&&!staffWorldData&&!staffWorldLoading\)\{/);
 assert.match(navSource,/void loadStaffWorld\(\)\.then\(\(\)=>\{if\(route==='staff'\)render\(\)\}\)/);
 assert.doesNotMatch(navSource,/if\(r==='staff'&&!staffWorldData\)\{\s*loading/);

 let releaseMarket;
 const marketPending=new Promise(resolve=>{releaseMarket=resolve});
 const actions=[];
 const win={scrollTo(){}};
 const nav=new Function('window','loadBootstrapSecondary','loadStaffWorld','render',`
   let route='home',staffWorldData=null,staffWorldLoading=false;
   ${navSource}
   return window.nav;
 `)(win,
   async()=>{actions.push('bootstrap')},
   async()=>{actions.push('market-start');await marketPending;actions.push('market-end')},
   ()=>{actions.push('render')}
 );
 // The market promise intentionally remains unresolved while navigation finishes.
 await nav('staff');
 assert.deepEqual(actions,['bootstrap','market-start','render']);
 releaseMarket();
 await new Promise(resolve=>setImmediate(resolve));
 assert.deepEqual(actions,['bootstrap','market-start','render','market-end','render']);
});

test('Staff route cannot erase other pages when background market arrives',async()=>{
 let releaseMarket;const pending=new Promise(resolve=>{releaseMarket=resolve});
 const win={scrollTo(){}};
 let renders=0;
 const nav=new Function('window','loadBootstrapSecondary','loadStaffWorld','render',`
   let route='home',staffWorldData=null,staffWorldLoading=false;
   ${navSource}
   return window.nav;
 `)(win,async()=>{},async()=>pending,()=>{renders++});
 await nav('staff');
 await nav('more');
 assert.equal(renders,2);
 releaseMarket();
 await new Promise(resolve=>setImmediate(resolve));
 assert.equal(renders,2,'background staff completion must not redraw an unrelated route');
});
