import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const a=app.indexOf('window.nav=async r=>');
const b=app.indexOf('async function syncLegacySinglesEntries(',a);
const nav=app.slice(a,b);
const c=app.indexOf('function staffPage(){');
const d=app.indexOf('function ',c+20);
const page=app.slice(c,d);

test('staff route renders before optional secondary bootstrap and global market',()=>{
 assert.ok(a>=0&&b>a);
 const staffStart=nav.indexOf("if(r==='staff'){");
 const remaining=nav.slice(staffStart);
 assert.ok(staffStart>0);
 assert.match(remaining,/void loadBootstrapSecondary\(\)/);
 assert.match(remaining,/\.then\(\(\)=>\{if\(route==='staff'\)render\(\)\}\)/);
 assert.match(remaining,/if\(r==='staff'&&!staffWorldData&&!staffWorldLoading\)/);
 assert.match(remaining,/void loadStaffWorld\(\)/);
 assert.doesNotMatch(remaining,/loading\('Chargement de la base mondiale du staff/);
 assert.match(nav,/await render\(\)/);
});
test('staff route keeps missing data visibly loading rather than pretending no staff exist',()=>{
 assert.match(page,/boot\?\.secondary_loaded===true/);
 assert.match(page,/role="status"/);
 assert.match(page,/Chargement des informations complémentaires/);
 assert.match(app,/if\(!d\)return .*Chargement de la base mondiale du staff/);
});
test('no save or daily tick semantics are altered by staff navigation',()=>{
 assert.doesNotMatch(nav,/advance_career_day_v26|commit_live_world_match_atomic_v23/);
 assert.match(nav,/if\(r==='saves'\|\|r==='launcher'\)await loadSaveSlots\(\)/);
});
