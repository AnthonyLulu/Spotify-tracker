import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync('supabase/functions/court-boss/index.ts','utf8');
const app=fs.readFileSync('court-boss/app.js','utf8');

const coreStart=edge.indexOf('if(path.endsWith("/api/bootstrap")&&req.method==="GET")');
const secondaryStart=edge.indexOf('if(path.endsWith("/api/bootstrap-secondary")&&req.method==="GET")',coreStart);
const rankingsStart=edge.indexOf('if(path.endsWith("/api/rankings")',secondaryStart);
const core=edge.slice(coreStart,secondaryStart);
const secondary=edge.slice(secondaryStart,rankingsStart);

test('startup core bootstrap stays small and read-only',()=>{
  assert.ok(coreStart>=0&&secondaryStart>coreStart,'bootstrap endpoints must exist');
  assert.match(core,/CB-BOOTSTRAP-CORE-v2/);
  assert.ok((core.match(/db\.from\(/g)||[]).length<=11,'core bootstrap grew past its query budget');
  for(const heavy of ['staff_profiles','scouting_reports','match_history','injuries','davis_squad','medical_plan']){
    assert.doesNotMatch(core,new RegExp(heavy),heavy+' must stay out of core bootstrap');
    assert.match(secondary,new RegExp(heavy),heavy+' must live in secondary bootstrap');
  }
  assert.doesNotMatch(core,/\.insert\(|\.update\(|\.delete\(|\.upsert\(/);
});

test('home paints before optional secondary hydration',()=>{
  const initStart=app.indexOf('async function init()');
  const initEnd=app.indexOf('async function loadManagement()',initStart);
  const init=app.slice(initStart,initEnd);
  assert.ok(init.indexOf('render();')>=0);
  assert.ok(init.indexOf('loadBootstrapSecondary()')>init.indexOf('render();'),'secondary hydration must start after first paint');
  assert.match(init,/authPrompt:false,method:'POST'/);
});

test('secondary bootstrap is shared and awaited only by dependent routes',()=>{
  assert.match(app,/let bootstrapSecondaryPromise=null/);
  assert.match(app,/if\(bootstrapSecondaryPromise&&!force\)return bootstrapSecondaryPromise/);
  assert.match(app,/get\('\/api\/bootstrap-secondary'\)/);
  assert.match(app,/\['academy','scouting','staff','finance','medical','davis','match','players','contracts'\]\.includes\(r\)/);
  assert.match(app,/await loadBootstrapSecondary\(\)/);
});

test('core refresh preserves already-hydrated secondary data',()=>{
  assert.match(app,/function mergeBootstrapCore/);
  assert.match(app,/previous\?\.secondary_loaded===true&&data\?\.secondary_loaded===false/);
  assert.doesNotMatch(app,/boot=await get\('\/api\/bootstrap'\)/);
});
