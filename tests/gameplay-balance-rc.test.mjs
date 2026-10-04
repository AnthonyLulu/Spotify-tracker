import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const edge=read('supabase/functions/court-boss/index.ts');

const eloWin=(gap)=>1/(1+Math.pow(10,-gap/400));
const finalWorldProb=(gap)=>Math.max(.035,Math.min(.965,eloWin(gap)));

test('world simulation keeps a realistic upset floor instead of deterministic favourites',()=>{
  assert.match(edge,/const eloProb=1\/\(1\+Math\.pow\(10,\(bElo-aElo\)\/400\)\)/);
  assert.match(edge,/probA=Math\.max\(\.035,Math\.min\(\.965,probA\)\)/);

  assert.equal(eloWin(0),.5);
  assert.ok(eloWin(100)>.63&&eloWin(100)<.65);
  assert.ok(eloWin(200)>.75&&eloWin(200)<.77);
  assert.ok(eloWin(300)>.84&&eloWin(300)<.86);
  assert.ok(eloWin(400)>.90&&eloWin(400)<.92);

  // Even an enormous 600-Elo mismatch remains playable: the underdog has a
  // 3.5% floor rather than a scripted loss. A normal 400-Elo mismatch still
  // leaves roughly a one-in-eleven upset before contextual modifiers.
  assert.equal(finalWorldProb(600),.965);
  assert.ok(1-finalWorldProb(600)>=.035-1e-12);
  assert.ok(1-finalWorldProb(400)>.08&&1-finalWorldProb(400)<.10);
});

test('surface form fatigue mental and tactics all enter the same world match model',()=>{
  for(const marker of [
    'serviceReturn*.54',
    'mental*.20',
    'physical*.16',
    'surfaceFit*.20',
    'styleMatch*.38',
    'tacticalFit*.42',
    'contextFit*.18',
    'bigMatchFit*.16',
    'bo5Fit*.22',
    'confidenceFit',
    'paceFit',
    'h2h',
    'formDelta',
    'userTactics',
    'extendedAttributeFit'
  ]) assert.ok(edge.includes(marker),'missing matchup component '+marker);

  assert.match(edge,/Number\(a\.fitness\|\|90\)-Number\(a\.fatigue\|\|20\)\*\.55/);
  assert.match(edge,/if\(Number\(c\.fatigue\|\|18\)>45&&tacticAgg>75\)bonus-=2\.8/);
  assert.match(edge,/if\(tacticRisk>80\)bonus-=1\.8/);
});

test('contextual modifiers are bounded so one gimmick cannot become a cheat code',()=>{
  assert.match(edge,/extendedAttributeFit=Math\.max\(-\.14,Math\.min\(\.14,/);
  assert.match(edge,/Math\.min\(\.055,total\*\.007\)/);
  assert.match(edge,/Math\.min\(\.045,sn\*\.009\)/);
  assert.match(edge,/Math\.min\(\.025,rn\*\.006\)/);

  // Point-by-point live play has its own safety rails too.
  assert.match(edge,/pointAttrEdge=Math\.max\(-\.06,Math\.min\(\.06,/);
  assert.match(edge,/opponentMemoryEdge=Math\.max\(-\.034,Math\.min\(\.026,/);
  assert.match(edge,/styleMatchupEdge=Math\.max\(-\.025,Math\.min\(\.025,/);
  assert.match(edge,/userStyleFitEdge=Math\.max\(-\.018,Math\.min\(\.018,userStyleFitEdge\)\)/);
  assert.match(edge,/conditionEdge=\(serverIsUser\?userCondition-oppCondition:oppCondition-userCondition\)\*\.018/);
  assert.match(edge,/serverWinProb=Math\.max\(\.25,Math\.min\(\.92,serverWinProb\)\)/);
});

test('best-of-five rewards the stronger profile without removing comeback variance',()=>{
  assert.match(edge,/if\(bestOf>=5\)logit\*=1\.10/);
  const p400=finalWorldProb(400);
  const boosted=1/(1+Math.exp(-Math.log(p400/(1-p400))*1.10));
  assert.ok(boosted>p400,'best of five should favour the stronger profile');
  assert.ok(boosted<.94,'best of five should not make a 400-Elo favourite deterministic');
});

test('doubles tactics stay influential but bounded',()=>{
  assert.match(edge,/Math\.max\(-2\.5,Math\.min\(2\.5,bonus\)\)/);
  const maxPlan=1/(1+Math.exp(-2.5/8));
  assert.ok(maxPlan>.56&&maxPlan<.59);
});
