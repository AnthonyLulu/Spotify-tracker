import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const begin=app.indexOf('window.nav=async r=>');
const end=app.indexOf('async function syncLegacySinglesEntries(',begin);
const route=app.slice(begin,end);
const staffBegin=app.indexOf('function staffPage(){');
const staffEnd=app.indexOf('function ',staffBegin+20);
const staff=app.slice(staffBegin,staffEnd);

test('the managed Staff screen no longer awaits optional secondary bootstrap',()=>{
  assert.ok(begin>=0&&end>begin);
  assert.match(route,/if\(r==='staff'\)\{/);
  assert.match(route,/void loadBootstrapSecondary\(\)/);
  assert.match(route,/\.then\(\(\)=>\{if\(route==='staff'\)render\(\)\}\)/);
  assert.match(route,/else if\(\['academy','scouting','finance','medical','davis','match','contracts'\]/);
  assert.match(route,/await render\(\)/);
});

test('the current global staff catalog remains asynchronously loaded as in PR 36',()=>{
  assert.match(route,/if\(r==='staff'&&!staffWorldData&&!staffWorldLoading\)/);
  assert.match(route,/void loadStaffWorld\(\)/);
  assert.doesNotMatch(route,/loading\('Chargement de la base mondiale du staff/);
});

test('secondary hydration is visibly pending rather than a fake empty result',()=>{
  assert.match(staff,/boot\?\.secondary_loaded===true/);
  assert.match(staff,/role="status"/);
  assert.match(staff,/Informations complémentaires de l’équipe en cours de chargement/);
});
