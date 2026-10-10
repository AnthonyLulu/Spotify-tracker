import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const start=app.indexOf('async function loadDoublesHub(){');
const end=app.indexOf('\nfunction career(){',start);
assert.ok(start>=0&&end>start,'real Double hub implementation present');
const liveCode=app.slice(start,end);

function harness(respond){
 const hits=[];
 let renderCount=0;
 const context=vm.createContext({
  window:{},
  Promise,
  console:{warn:()=>{}},
  route:'doubles',
  render:()=>{renderCount++},
  get:async path=>{hits.push(path);return respond(path)},
 });
 vm.runInContext(`
  let doublesHubRows=[],juniorDoublesHubRows=[],doublesRaceRows=[];
  let doublesHubLoading=false,doublesHubAttempted=false,doublesHubError='';
  ${liveCode}
  globalThis.state=()=>({rows:doublesHubRows.length,juniors:juniorDoublesHubRows.length,
   race:doublesRaceRows.length,loading:doublesHubLoading,
   attempted:doublesHubAttempted,error:doublesHubError});
 `,context);
 return {run:()=>vm.runInContext('loadDoublesHub()',context),state:()=>context.state(),
  get calls(){return hits},get renders(){return renderCount},retry:context.window.retryDoublesHub};
}

test('Double hub shows partial data after one API rejects, instead of endless automatic retries',async()=>{
 const h=harness(path=>{
  if(path.includes('kind=doubles'))return {rows:[{id:7,name:'Paire A'}]};
  if(path.includes('kind=junior_doubles'))throw new Error('HTTP 503');
  return {rows:[{rank:1,doubles_race_ranking:2,doubles_race_points:567}]};
 });
 await h.run();
 assert.equal(h.calls.length,3);
 assert.equal(h.renders,1);
 assert.deepEqual([h.state().rows,h.state().juniors,h.state().race],[1,0,1]);
 assert.match(h.state().error,/Junior Double/);
 assert.equal(h.state().attempted,true);
 assert.equal(h.state().loading,false);
});

test('all empty successful endpoints are considered attempted and do not force refetch',async()=>{
 const h=harness(()=>({rows:[]}));
 await h.run();
 assert.equal(h.state().attempted,true);
 assert.equal(h.state().error,'');
 assert.equal(h.calls.length,3);
 assert.equal(h.renders,1);
 assert.match(app,/if\(!doublesHubAttempted&&!doublesHubLoading\)\{doublesHubAttempted=true;setTimeout\(loadDoublesHub,0\);\}/);
 assert.doesNotMatch(app,/if\(!doublesHubRows\.length&&!doublesHubLoading\)setTimeout\(loadDoublesHub,0\)/);
});

test('a user-requested retry can recover independently failed Double APIs',async()=>{
 let failing=true;
 const h=harness(path=>{
  if(failing)throw new Error('temporary API outage');
  return {rows:[{id:9,rank:1}]};
 });
 await h.run();
 assert.equal(h.calls.length,3);
 assert.match(h.state().error,/Classement Double/);
 failing=false;
 await h.run();
 assert.equal(h.calls.length,6);
 assert.equal(h.state().error,'');
 assert.deepEqual([h.state().rows,h.state().juniors,h.state().race],[1,1,1]);
 assert.equal(typeof h.retry,'function');
 assert.match(app,/onclick="retryDoublesHub\(\)"/);
 assert.match(app,/doublesHubAttempted=false;doublesHubError=''/);
});
