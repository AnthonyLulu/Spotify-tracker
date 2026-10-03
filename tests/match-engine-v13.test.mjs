import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');
const backend=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');
const v1=read('court-boss/match-center-v1.js');
const v12=read('court-boss/match-center-v12.js');
const v13=read('court-boss/match-center-v13.js');
const play=read('court-boss/play.html');

test('all Match Center browser scripts parse',()=>{
  for(const [name,source] of [['app',app],['v1',v1],['v12',v12],['v13',v13]]){
    assert.doesNotThrow(()=>new Function(source),name+' should parse');
  }
});

test('V13 production page loads the live doubles stack with fresh cache keys',()=>{
  assert.match(play,/app\.js\?v=20261003-live-doubles-v1/);
  assert.match(play,/match-center-v1\.js\?v=20261003-living-arena-v13/);
  assert.match(play,/match-center-v12\.js\?v=20261003-tactical-ai-v5/);
  assert.match(play,/match-center-v13\.js\?v=20261003-live-doubles-v1/);
  assert.match(play,/match-center-v13\.css\?v=20261003-live-doubles-v1/);
});

test('match kernel advertises and contains the new causal layers',()=>{
  for(const marker of [
    'h2h-memory-v1','situational-rules-v1','environment-events-v1',
    'player-identity-v1','doubles-visual-v2','liveSituationalTactics',
    'h2h_memory','medical_timeout','time_violation','electronic_review',
    'CB-DOUBLES-VISUAL-v2'
  ]) assert.ok(backend.includes(marker),'missing '+marker);
});

test('opponent tactical memory stays bounded and can be fooled',()=>{
  assert.match(backend,/Math\.max\(-\.034,Math\.min\(\.026,rawMemoryEdge\*deceptionBoost\)\)/);
  assert.match(backend,/IA piégée par ton switch/);
  assert.match(backend,/deception_window_points/);
});

test('doubles tactical plan bonus is capped and not a cheat code',()=>{
  assert.match(backend,/Math\.max\(-2\.5,Math\.min\(2\.5,bonus\)\)/);
  const p=bonus=>1/(1+Math.exp(-bonus/8));
  assert.ok(p(2.5)<.58&&p(2.5)>.56);
  assert.ok(p(-2.5)>.42&&p(-2.5)<.44);
  assert.equal(p(0),.5);
});

test('100000 seeded equal-strength doubles trials remain sane under max plan bonus',()=>{
  let state=0xC0FFEE;
  const rand=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296};
  const trials=100000,p=1/(1+Math.exp(-2.5/8));
  let wins=0;
  for(let i=0;i<trials;i++)if(rand()<p)wins++;
  const rate=wins/trials;
  assert.ok(rate>.56&&rate<.59,'max tactical plan rate='+rate);
});

test('manager UI exposes conditional tactics, H2H read, heatmap and four-dot doubles',()=>{
  for(const marker of [
    'Attaquer 2e balle','Points chauds','Protéger avance','Mode remontée',
    'H2H mémorisé','cb-heat-v13','cbDoublesReplayHtmlV13',
    'Poach agressif','Formation australienne','Cibler le plus faible'
  ]) assert.ok(v13.includes(marker),'missing '+marker);
});

test('player movement is eased while ball flight remains linear',()=>{
  assert.match(v1,/oppAnim\} \$\{visualMs\}ms cubic-bezier/);
  assert.match(v1,/userAnim\} \$\{visualMs\}ms cubic-bezier/);
  assert.match(v1,/ballAnim\} \$\{visualMs\}ms linear both/);
});


test('live doubles point-by-point uses the real match stack',()=>{
  for(const marker of [
    '/api/live-doubles/start','/api/live-doubles/point','/api/live-doubles/commit',
    'CB-LIVE-DOUBLES-v1','doubles_pair_matchup_v2','tennis_abstract_matchup_model_v2',
    'baseline_probability','user_pair_elo','opponent_pair_elo',
    '_doubles_rotation','_doubles_player_stats','match_tiebreak_points=10',
    'no_ad_rule="atp_doubles"'
  ]) assert.ok(backend.includes(marker),'missing '+marker);
  assert.ok(app.includes("liveIsDoubles(session)?'/api/live-doubles/point'"));
  assert.ok(app.includes("liveIsDoubles(session)?'/api/live-doubles/commit'"));
  assert.ok(app.includes('startTournamentLiveDoubles'));
  assert.ok(v13.includes('cb-live-double-partner-v13'));
  assert.ok(v13.includes('cbSetLiveDoublesPlanV13'));
});

test('live doubles level blends attributes, Elo, chemistry and active point matchup',()=>{
  assert.match(backend,/attrProb\*\.72\+eloProb\*\.28/);
  assert.match(backend,/de\*\.72\+se\*\.28/);
  assert.match(backend,/userNetScore-oppNetScore/);
  assert.match(backend,/dmeta\.chemistry/);
  assert.match(backend,/kernel\.serverWinProb/);
  assert.match(backend,/update_player_elo_after_match/);
});

test('double live scoring keeps no-ad and deciding match tie-break',()=>{
  assert.match(backend,/environment\.no_ad=true/);
  assert.match(backend,/environment\.match_tiebreak_decider=true/);
  assert.match(backend,/environment\.match_tiebreak_points=10/);
  assert.match(backend,/gameFinished=up>=4\|\|op>=4/);
  assert.match(backend,/tbTarget/);
});
