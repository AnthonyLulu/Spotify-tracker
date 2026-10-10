import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const start=edge.indexOf('if(path.endsWith("/api/career-hub")');
const end=edge.indexOf('if(path.endsWith("/api/managed-player-context")',start);
assert.ok(start>=0&&end>start);
const careerRoute=edge.slice(start,end);

test('Career Hub fails closed for missing career and players, not optional data',()=>{
  assert.ok(careerRoute.includes('if(career.error||!career.data)return h({error:'));
  assert.ok(careerRoute.includes('if(managedPlayer.error||!managedPlayer.data)return h({error:'));
  assert.ok(careerRoute.includes('if(roster.error)return h({error:roster.error.message},500)'));
  assert.ok(careerRoute.includes('const careerHubSections=['));
  assert.ok(careerRoute.includes('const unavailableSections=careerHubSections'));
  assert.ok(careerRoute.includes('partial_data:unavailableSections.length>0'));
  assert.ok(careerRoute.includes('unavailable_sections:unavailableSections'));
  assert.ok(!careerRoute.includes('if(err)return h({error:err.message},500)'));
  for(const name of ['health','integrity','season_plan','media','sponsors','board','timeline','relationships','academy','medical_plan'])
    assert.ok(careerRoute.includes('["'+name+'",'),'Optional section not handled: '+name);
});

test('real render function surfaces degraded Career Hub without obscuring other pages',()=>{
  const from=app.indexOf('function render(){'),to=app.indexOf('\n\nfunction playerStatsAdvancedSections(',from);
  assert.ok(from>=0&&to>from);
  const fn=app.slice(from,to);
  const views=fn.match(/const views=\{([^}]+)\}/)?.[1];
  assert.ok(views);
  const names=views.split(',').map(p=>p.includes(':')?p.split(':')[1].trim():p.trim());
  let html='';
  const context={route:'careerhub',boot:{},careerHub:{partial_data:true,unavailable_sections:['media','sponsors']},
    shell:s=>{html=s},esc:s=>String(s).replaceAll('<','&lt;')};
  for(const n of names)context[n]=()=>'<main class="test-view">CONTENT '+n+'</main>';
  vm.runInNewContext(fn,context);
  vm.runInNewContext('render()',context);
  assert.match(html,/Certaines données du bureau manager/);
  assert.match(html,/media, sponsors/);
  assert.match(html,/CONTENT careerHubPage/);
  context.route='home';
  vm.runInNewContext('render()',context);
  assert.doesNotMatch(html,/Certaines données du bureau manager/);
  assert.match(html,/CONTENT home/);
  context.route='careerhub';context.careerHub={partial_data:false,unavailable_sections:[]};
  vm.runInNewContext('render()',context);
  assert.doesNotMatch(html,/Certaines données du bureau manager/);
});
