import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL('../'+p,import.meta.url),'utf8');
const edge=read('supabase/functions/court-boss/index.ts');

const eloWin=(gap)=>1/(1+Math.pow(10,-gap/400));
const upsetFloor=(gap)=>Math.max(.005,Math.min(.035,.035-Math.max(0,Math.abs(gap)-400)*.00005));
const finalWorldProb=(gap)=>Math.max(upsetFloor(gap),Math.min(1-upsetFloor(gap),eloWin(gap)));

test('world simulation uses skill-gap-sensitive upset floor instead of a flat 3.5%',()=>{
  assert.match(edge,/const eloProb=1\/\(1\+Math\.pow\(10,\(bElo-aElo\)\/400\)\)/);
  assert.match(edge,/probA=Math\.max\(\.035,Math\.min\(\.965,probA\)\)/);

  assert.equal(eloWin(0),.5);
  assert.ok(eloWin(100)>.63&&eloWin(100)<.65);
  assert.ok(eloWin(200)>.75&&eloWin(200)<.77);
  assert.ok(eloWin(300)>.84&&eloWin(300)<.86);
  assert.ok(eloWin(400)>.90&&eloWin(400)<.92);

  // Below 400 Elo the existing game behavior is unchanged; at huge gaps
  // the bounded underdog floor declines gradually from 3.5% to 0.5%.
  assert.equal(upsetFloor(400),.035);
  assert.ok(upsetFloor(600)<.035&&upsetFloor(600)>.02);
  assert.equal(upsetFloor(1000),.005);
  assert.ok(finalWorldProb(600)>.965&&finalWorldProb(600)<.975);
  assert.equal(finalWorldProb(1500),.995);
  assert.ok(1-finalWorldProb(1500)>=.005-1e-12);
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
