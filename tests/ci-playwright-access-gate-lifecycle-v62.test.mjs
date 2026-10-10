import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const smoke=fs.readFileSync(new URL('../.github/workflows/court-boss-pages.yml',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');

test('disposable browser smoke dismisses repeated auth gates without changing production access',()=>{
 const ci=smoke.slice(smoke.indexOf('- name: Mobile browser smoke test'),smoke.indexOf('- name: ',smoke.indexOf('- name: Mobile browser smoke test')+10)>0?smoke.indexOf('- name: ',smoke.indexOf('- name: Mobile browser smoke test')+10):undefined);
 assert.match(ci,/await page\.addInitScript\(\(\)=>\{/);
 assert.match(ci,/new MutationObserver\(dismiss\)\.observe\(document\.documentElement/);
 assert.match(ci,/document\.querySelectorAll\('\.cb-access-gate'\)/);
 assert.match(ci,/document\.addEventListener\('DOMContentLoaded',watch,\{once:true\}\)/);
 assert.match(app,/cb-access-gate/,'the actual game still has the access prompt');
 assert.doesNotMatch(app,/new MutationObserver\(dismiss\)\.observe\(document\.documentElement/);
});
