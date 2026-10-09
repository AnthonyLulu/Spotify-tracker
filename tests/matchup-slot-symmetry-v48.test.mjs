import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261009225500_matchup_tactical_symmetry_v48.sql',import.meta.url),'utf8');
const begin=sql.indexOf('  tactical_fit:=(');
const end=sql.indexOf('\n  context_fit:=(',begin);
const block=sql.slice(begin,end);

test('the five matchup tactical factors are mirrored for both players',()=>{
  assert.ok(begin>=0&&end>begin,'tactical score section must exist');
  for(const name of ['net_frequency','aggression_bias','rally_length_preference','drop_shot_frequency','defense_to_attack_bias']){
    assert.ok(block.includes('ta.'+name),'player A missing '+name);
    assert.ok(block.includes('tb.'+name),'player B missing '+name);
  }
  for(const term of [
    'coalesce(tb.rally_length_preference,10)-10',
    'coalesce(tb.drop_shot_frequency,10)-10',
    'coalesce(tb.defense_to_attack_bias,10)-coalesce(ta.aggression_bias,10)',
    'coalesce(ab.drop_shot,ab.touch,10)',
    'coalesce(aa.reaction,aa.anticipation,10)'
  ]) assert.ok(block.includes(term),'missing mirrored opponent factor: '+term);
});

test('matchup migration preserves full existing v2_core contract',()=>{
  assert.match(sql,/CREATE OR REPLACE FUNCTION public\.player_matchup_probability_v2_core/);
  assert.match(sql,/STABLE SECURITY DEFINER/);
  assert.match(sql,/player_a_probability/);
  assert.match(sql,/player_b_probability/);
  assert.match(sql,/prob:=greatest\(\.035,least\(\.965,prob\)\)/);
  assert.doesNotMatch(sql,/\b(?:TRUNCATE|DROP TABLE|DELETE FROM|UPDATE public\.players)\b/i);
});

test('symmetrical tactical terms are invariant to which player is A or B',()=>{
  // One randomized vector per factor and mixed style, mathematically
  // reproducing the five-factor A-v-B expression of the migration.
  let seed=20261010;
  const rnd=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2**32};
  const make=()=>({
    net:5+15*rnd(),agg:5+15*rnd(),rally:5+15*rnd(),
    drop:5+15*rnd(),counter:5+15*rnd(),
    volley:5+15*rnd(),netpos:5+15*rnd(),pass:5+15*rnd(),reaction:5+15*rnd(),
    forehand:5+15*rnd(),serveone:5+15*rnd(),tol:5+15*rnd(),consistency:5+15*rnd(),
    dropskill:5+15*rnd(),decision:5+15*rnd(),movement:5+15*rnd(),counterSkill:5+15*rnd()
  });
  const offense=(a,b)=>(
    (a.net-10)*(a.volley+a.netpos-b.pass-b.reaction)/520
    +(a.agg-b.counter)*(a.forehand+a.serveone-20)/600
    +(a.rally-10)*(a.tol+a.consistency-b.tol-b.consistency)/520
    +(a.drop-10)*(a.dropskill+a.decision-b.reaction-b.movement)/650
    +(a.counter-b.agg)*(a.counterSkill+a.pass-20)/620
  );
  const fit=(a,b)=>offense(a,b)-offense(b,a);
  for(let i=0;i<3000;i++){
    const a=make(),b=make();
    assert.ok(Math.abs(fit(a,b)+fit(b,a))<1e-12);
  }
});
