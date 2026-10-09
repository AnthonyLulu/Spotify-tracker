import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=(p)=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const edge=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');
const ci=read('.github/workflows/court-boss-pr-ci.yml');
const smoke=read('.github/workflows/court-boss-pages.yml');
const juniorStart=edge.indexOf('if(kind==="junior"){',edge.indexOf('if(path.endsWith("/api/rankings")'));
const juniorEnd=edge.indexOf('let orderCol=kind==="singles"',juniorStart);
const route=edge.slice(juniorStart,juniorEnd);

test('junior ranking remains available when ancillary counts time out',()=>{
  assert.ok(juniorStart>0&&juniorEnd>juniorStart);
  assert.match(route,/Promise\.allSettled\(/);
  assert.match(route,/select\("id",\{count:"planned",head:true\}\)/);
  assert.match(route,/generatedReserveEstimated:true/);
  assert.match(route,/if\(page\.error\)return h\(\{error:page\.error\.message\},500\)/);
  assert.match(route,/const metadataPartial=/);
  assert.match(route,/const safeCount=\(r:any\)=>r\.error\|\|r\.count==null\?null:Number\(r\.count\)/);
  assert.doesNotMatch(route,/page\.error\|\|officialCount\.error/);
  assert.match(route,/generatedReserve:generatedReserveTotal==null\|\|generated==null\?null/);
});

test('junior UI discloses unavailable counts instead of showing zero',()=>{
  assert.match(app,/rankMeta\?\.metadataPartial\?"Statistiques du vivier momentanément indisponibles/);
});

test('smoke reports the failing read endpoint, retries transient overload, and eventually fails',()=>{
  const at=smoke.indexOf('      - name: Check live backend');
  const block=smoke.slice(at,smoke.indexOf('      - name: Mobile browser smoke test',at));
  assert.match(block,/fetch_backend\(\)/);
  assert.match(block,/for attempt in 1 2 3/);
  assert.match(block,/::error:: Backend GET failed/);
  assert.match(block,/fetch_backend "\$API\/api\/rankings\?kind=\$kind&offset=0&limit=10"/);
  assert.match(block,/return 1/);
});

test('P0 pull-request gates never publish changes to live',()=>{
  assert.match(ci,/pull_request:/);
  assert.match(ci,/branches: \[court-boss-live\]/);
  assert.match(ci,/node --test tests\/\*\.test\.mjs/);
  assert.doesNotMatch(ci,/deploy|publish|service_role/i);
});

test('save/load retains digest-verification and never claims an unverified rollback',()=>{
  const start=edge.indexOf('if(path.endsWith("/api/load-slot")');
  const stop=edge.indexOf('if(path.endsWith("/api/delete-slot")',start);
  const load=edge.slice(start,stop);
  assert.match(load,/rollbackRecovered=rollbackDigest===safetyDigest&&legacyRollbackDigest===legacySafetyDigest/);
  assert.match(load,/rollback_verified:rollbackRecovered/);
  assert.match(load,/rollback_error:rollbackError\|\|null/);
  assert.match(app,/rollback_verification_failed/);
});
