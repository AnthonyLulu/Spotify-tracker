import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const routeStart=app.indexOf('window.nav=async r=>{');
const routeEnd=app.indexOf('async function syncLegacySinglesEntries(',routeStart);
assert.ok(routeStart>0&&routeEnd>routeStart,'Expected real Court Boss route function');
const liveNav=app.slice(routeStart,routeEnd);
const previewStart=app.indexOf('async function loadTrainingPreview(');
const previewEnd=app.indexOf('const TRAINING_SESSIONS_V22=',previewStart);
assert.ok(previewStart>=0&&previewEnd>previewStart);
const livePreview=app.slice(previewStart,previewEnd);

test('training staff preview never forces the private access gate on page open',()=>{
  assert.match(livePreview,/get\\('\/api\/training-preview',\\{/);
  assert.match(livePreview,/authPrompt:false/);
  assert.match(liveNav,/void loadTrainingPreview\\(\\)/);
  assert.doesNotMatch(liveNav,/if\\(r==='training'&&![^\\n]*\\)await loadTrainingPreview/);
});

test('actual nav(training) renders immediately while staff preview has not responded',async()=>{
  let finish;
  const pending=new Promise(resolve=>{finish=resolve});
  const renders=[];
  const ctx={
    window:{scrollTo:()=>{}},
    route:'home',
    trainingPreview:null,
    loadTrainingPreview:()=>pending,
    render:()=>{renders.push('render')},
    console:{warn:()=>{}}
  };
  vm.runInNewContext(liveNav,ctx);
  const navigation=ctx.window.nav('training');
  const completed=await Promise.race([
    navigation.then(()=>true),
    new Promise((_,reject)=>setTimeout(()=>reject(new Error('nav(training) still blocked by preview')),300))
  ]);
  assert.equal(completed,true);
  assert.equal(ctx.route,'training');
  assert.equal(renders.length,1,'the local training plan should render before the backend finishes');
  finish({ok:true});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(renders.length,2,'staff preview completion should refresh the visible page');
});

test('late staff preview response never redraws an unrelated page',async()=>{
  let finish;
  const pending=new Promise(resolve=>{finish=resolve});
  let renders=0;
  const ctx={
    window:{scrollTo:()=>{}},
    route:'home',
    trainingPreview:null,
    loadTrainingPreview:()=>pending,
    render:()=>{renders++},
    console:{warn:()=>{}}
  };
  vm.runInNewContext(liveNav,ctx);
  await ctx.window.nav('training');
  assert.equal(renders,1);
  ctx.route='home';
  finish({});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(renders,1,'stale training preview must not repaint a new screen');
});
