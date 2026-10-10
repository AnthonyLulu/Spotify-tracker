import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const root=new URL('../.github/workflows/',import.meta.url);
const read=file=>fs.readFileSync(new URL(file,root),'utf8');
const heavy=['court-boss-pages.yml','court-boss-mobile-ux-rc.yml','court-boss-visual-assets.yml'];
const header=yaml=>yaml.slice(0,yaml.indexOf('\npermissions:'));
test('heavy production browser and backend checks remain manually gated during Disk IO alert',()=>{
 for(const name of heavy){
  const y=read(name),h=header(y);
  assert.match(h,/workflow_dispatch:/,'manual trigger must be present: '+name);
  assert.doesNotMatch(h,/^\s*push:/m,'must not hit live DB on each merge: '+name);
  assert.doesNotMatch(h,/^\s*schedule:/m,'must not schedule expensive DB reads: '+name);
  assert.match(y,/(playwright|Check live backend)/i,'keep manual validation available: '+name);
 }
});
test('offline PR and push gates remain automatic without network calls',()=>{
 const y=read('court-boss-pr-ci.yml'),h=header(y);
 assert.match(h,/pull_request:/);
 assert.match(h,/push:/);
 assert.match(y,/node --test tests\/\*\.test\.mjs/);
 assert.doesNotMatch(y,/https?:\/\//,'offline CI should not request URLs');
});
