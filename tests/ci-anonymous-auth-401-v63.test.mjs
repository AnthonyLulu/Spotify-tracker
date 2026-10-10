import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const workflow=fs.readFileSync(new URL('../.github/workflows/court-boss-pages.yml',import.meta.url),'utf8');
test('anonymous UI smoke accepts only expected auth 401, not unrelated 401s or API 500s',()=>{
 const section=workflow.slice(workflow.indexOf('cat > mobile-smoke.cjs'),workflow.indexOf('node mobile-smoke.cjs'));
 assert.match(section,/const anonymousProtected401=status===401&&/);
 assert.match(section,/endpoint\.endsWith\('\/api\/save'\)/);
 assert.match(section,/endpoint\.endsWith\('\/api\/training-preview'\)/);
 assert.match(section,/if\(status>=400&&!anonymousProtected401\)/);
 assert.match(section,/pageErrors\.push\('http '\+status\+': '\+url\)/);
 const classify=(status,path)=>status>=400&&!(status===401&&['/api/save','/api/training-preview'].includes(path));
 for(const route of ['/api/save','/api/training-preview'])assert.equal(classify(401,route),false);
 for(const [status,path] of [[500,'/api/save'],[500,'/api/staff-world'],[401,'/api/players'],[403,'/api/save'],[502,'/api/training-preview']])assert.equal(classify(status,path),true);
});
