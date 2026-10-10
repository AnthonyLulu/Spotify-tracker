import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const start=source.indexOf('const get=async(path,opts={},retried=false,transientAttempt=0)=>{');
const end=source.indexOf('\nlet boot=',start);
const helper=source.slice(start,end);

function makeGet(fetchMock){
  const delays=[];
  const fakeTimer=(callback,ms)=>{delays.push(ms);callback()};
  const get=new Function('fetch','setTimeout','requestCourtBossAccess','localStorage',`
    const API='https://example.test'; const saveKey='browser:test'; let accessKey='';
    ${helper}
    return get;
  `)(fetchMock,fakeTimer,async()=>{}, {removeItem(){}});
  return {get,delays};
}
const response=(status,data={})=>({status,ok:status>=200&&status<300,json:async()=>data});

test('the helper is bounded and only retries read-only requests',()=>{
  assert.ok(start>=0&&end>start);
  assert.match(helper,/method==='GET'&&transientAttempt<2/);
  assert.match(helper,/\[500,502,503,504\]\.includes\(r\.status\)/);
  assert.match(helper,/return get\(path,\{\.\.\.fetchOpts,authPrompt\},retried,transientAttempt\+1\)/);
  assert.match(helper,/if\(r\.status===401&&!retried\)/);
  assert.match(helper,/'X-Save-Key':saveKey/);
});

test('a transient 500 followed by a 200 recovers the original response',async()=>{
  let requests=0;
  const {get,delays}=makeGet(async()=>{
    requests++;
    return requests===1?response(500,{error:'temporarily overloaded'}):response(200,{rows:[1,2]});
  });
  assert.deepEqual(await get('/api/tournaments'),{rows:[1,2]});
  assert.equal(requests,2);
  assert.deepEqual(delays,[450]);
});

test('a permanently failing GET stops after three total requests',async()=>{
  let requests=0;
  const {get,delays}=makeGet(async()=>{
    requests++;
    return response(500,{error:'persistent backend failure'});
  });
  await assert.rejects(()=>get('/api/staff-world'),/persistent backend failure/);
  assert.equal(requests,3);
  assert.deepEqual(delays,[450,900]);
});

test('write endpoints are never reissued after any HTTP 500',async()=>{
  let requests=0;
  const {get,delays}=makeGet(async()=>{
    requests++;
    return response(500,{error:'write failed'});
  });
  await assert.rejects(()=>get('/api/save-slot',{method:'POST',body:'{}'}),/write failed/);
  assert.equal(requests,1);
  assert.deepEqual(delays,[]);
});

test('GET network errors retry, POST network errors do not',async()=>{
  let n=0;
  const {get}=makeGet(async()=>{
    if(++n<3)throw new Error('network reset');
    return response(200,{ok:true});
  });
  assert.deepEqual(await get('/api/calendar'),{ok:true});
  assert.equal(n,3);

  let writes=0;
  const mutation=makeGet(async()=>{
    writes++;
    throw new Error('unknown commit state');
  });
  await assert.rejects(()=>mutation.get('/api/advance-day',{method:'POST'}),/unknown commit state/);
  assert.equal(writes,1);
  assert.deepEqual(mutation.delays,[]);
});

test('401 never triggers transient retries or silently unlocks protected data',async()=>{
  let requests=0;
  const {get,delays}=makeGet(async()=>{
    requests++;
    return response(401,{error:'Private career locked'});
  });
  await assert.rejects(async()=>{
    try{await get('/api/save-slots',{authPrompt:false})}catch(e){
      assert.equal(e.status,401);
      throw e;
    }
  },/Private career locked/);
  assert.equal(requests,1);
  assert.deepEqual(delays,[]);
});
