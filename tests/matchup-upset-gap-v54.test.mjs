import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../supabase/migrations/20261010011500_matchup_skill_gap_upset_floor_v54.sql',import.meta.url),'utf8');
const start=edge.indexOf('      const upsetFloor=');
const end=edge.indexOf(';',start);
assert.ok(start>=0&&end>start);
const fragment=edge.slice(start,end+1);
const actualFloor=new Function('aElo','bElo',fragment+'return upsetFloor;');
const fromSql=(a,b)=>Math.max(.005,Math.min(.035,.035-Math.max(0,Math.abs(a-b)-400)*.00005));
const clip=(p,f)=>Math.max(f,Math.min(1-f,p));
const eloWin=(a,b)=>1/(1+10**((b-a)/400));

test('Edge floor evaluates identically in both player orders for 10,000 Elo pairs',()=>{
  let seed=20261010;
  for(let i=0;i<10000;i++){
    seed=(Math.imul(seed,1664525)+1013904223)>>>0;
    const a=500+2000*(seed/2**32);
    seed=(Math.imul(seed,1664525)+1013904223)>>>0;
    const b=500+2000*(seed/2**32);
    const f=actualFloor(a,b);
    assert.ok(Math.abs(f-actualFloor(b,a))<1e-12);
    assert.ok(Math.abs(f-fromSql(a,b))<1e-12);
    const ab=clip(eloWin(a,b),f),ba=clip(eloWin(b,a),f);
    assert.ok(Math.abs(ab+ba-1)<1e-12,'changed Elo win chance on A/B swap');
  }
});

test('skill-gap floor is monotonic, bounded, and preserves routine matches',()=>{
  const gaps=[0,100,300,400,500,600,700,800,900,1000,1200,1500];
  let previous=Infinity;
  for(const gap of gaps){
    const floor=actualFloor(2100,2100-gap);
    assert.ok(floor>=.005-1e-12&&floor<=.035+1e-12);
    assert.ok(floor<=previous+1e-12);
    previous=floor;
  }
  assert.equal(actualFloor(2200,1800),.035);
  assert.ok(Math.abs(actualFloor(2200,1600)-.025)<1e-12);
  assert.ok(Math.abs(actualFloor(2200,1200)-.005)<1e-12);
  assert.ok(clip(eloWin(2200,1600),actualFloor(2200,1600))>.965);
  assert.equal(clip(eloWin(2500,1000),actualFloor(2500,1000)),.995);
});

test('migration patches all SQL wrappers only after strict guards',()=>{
  for(const name of ['player_matchup_probability_v2_core','player_matchup_probability_v2','player_matchup_probability_v3','player_matchup_probability_v4'])
    assert.ok(migration.includes("'"+name+"'"),'Missing SQL model '+name);
  assert.ok(migration.includes('oidvectortypes(p.proargtypes)'));
  assert.ok(migration.includes('Probability clamp changed upstream'));
  assert.ok(migration.includes('Ambiguous probability clamp'));
  assert.ok(migration.includes("abs(aelo-belo)"));
  assert.ok(migration.includes("surface_elo_a"));
  assert.ok(migration.includes("surface_elo_b"));
  assert.ok(migration.includes('.00005'));
  assert.match(migration,/EXECUTE fn_def;/);
  assert.doesNotMatch(migration,/\b(?:DROP TABLE|TRUNCATE|DELETE FROM|UPDATE public\.players|UPDATE public\.game_saves)\b/i);
});
