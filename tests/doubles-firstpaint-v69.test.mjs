import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const start=source.indexOf('window.nav=async r=>{');
const end=source.indexOf('\nasync function syncLegacySinglesEntries',start);
const navCode=source.slice(start,end);
const pageStart=source.indexOf('function doublesPage(){');
const pageEnd=source.indexOf('\nfunction ',pageStart+20);
const doublesTemplate=source.slice(pageStart,pageEnd);

function harness(){
 let marks=[],jobs=[];
 const nav=new Function('render','setTimeout','loadDoublesHub',`
   let route='home',doublesHubAttempted=false,doublesHubLoading=false;
   const window={scrollTo(){}};
   ${navCode}
   return window.nav;
 `)(()=>{marks.push('render')},fn=>{marks.push('scheduled');jobs.push(fn)},
     ()=>{marks.push('fetch')});
 return {nav,marks,jobs};
}

test('initial Double route paints before optional ranking fetch and resolves promptly',async()=>{
 const x=harness();
 await x.nav('doubles');
 assert.deepEqual(x.marks,['render','scheduled']);
 assert.equal(x.jobs.length,1);
 x.jobs[0]();
 assert.deepEqual(x.marks,['render','scheduled','fetch']);
});

test('multiple route refreshes do not create another automatic fetch',async()=>{
 const x=harness();
 await x.nav('doubles');
 await x.nav('doubles');
 assert.deepEqual(x.marks,['render','scheduled','render']);
 assert.equal(x.jobs.length,1);
});

test('Double page templates are pure and never fetch from render',()=>{
 assert.ok(pageStart>=0&&pageEnd>pageStart);
 assert.doesNotMatch(doublesTemplate,/setTimeout\(loadDoublesHub/);
 assert.doesNotMatch(doublesTemplate,/get\('\/api\//);
 assert.match(navCode,/if\(r==='doubles'&&route==='doubles'&&!doublesHubAttempted&&!doublesHubLoading\)/);
});
