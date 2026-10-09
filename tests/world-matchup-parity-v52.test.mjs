import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const sql=fs.readFileSync(new URL('../supabase/migrations/20261009225500_matchup_tactical_symmetry_v48.sql',import.meta.url),'utf8');
const start=edge.indexOf('      const tacticalFit=');
const end=edge.indexOf('\n\n      let contextFit=',start);
assert.ok(start>=0 && end>start,'Automatic tournament matchup tactical block not found');
const formula=edge.slice(start,end);
const runTactical=new Function('ta','tb','aa','ab',formula+'\nreturn tacticalFit;');
const player=(r)=>({
  tactic:{net_frequency:r(),aggression_bias:r(),rally_length_preference:r(),drop_shot_frequency:r(),defense_to_attack_bias:r()},
  attr:{volley:r(),net_positioning:r(),passing_shot:r(),reaction:r(),anticipation:r(),forehand_power:r(),forehand:r(),serve_plus_one:r(),rally_tolerance:r(),stamina:r(),consistency:r(),concentration:r(),drop_shot:r(),touch:r(),decision_making:r(),tactics:r(),movement:r(),defense_to_attack:r(),return_game:r()}
});

test('SQL and actual Edge tournament code mirror all five tactical inputs',()=>{
  for(const field of ['net_frequency','aggression_bias','rally_length_preference','drop_shot_frequency','defense_to_attack_bias']){
    assert.match(formula,new RegExp('ta\\.'+field));
    assert.match(formula,new RegExp('tb\\.'+field));
    assert.match(sql,new RegExp('ta\\.'+field));
    assert.match(sql,new RegExp('tb\\.'+field));
  }
  for(const term of [
    'tb.rally_length_preference||10',
    'tb.drop_shot_frequency||10',
    'tb.defense_to_attack_bias||10',
    'ab.drop_shot??ab.touch??10',
    'aa.reaction??aa.anticipation??10'
  ]) assert.ok(formula.includes(term),'Missing mirrored factor in Edge simulator: '+term);
});

test('execute actual Edge tactical formula for 10000 pairs and reversed order',()=>{
  let seed=20261010;
  const rng=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return 2+18*(seed/2**32)};
  for(let i=0;i<10000;i++){
    const a=player(rng),b=player(rng);
    const ab=runTactical(a.tactic,b.tactic,a.attr,b.attr);
    const ba=runTactical(b.tactic,a.tactic,b.attr,a.attr);
    assert.ok(Number.isFinite(ab)&&Number.isFinite(ba));
    assert.ok(Math.abs(ab+ba)<1e-12,
      'A/B order changed tactical strength for pair '+i+': '+ab+' / '+ba);
  }
});
