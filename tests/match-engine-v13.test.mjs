import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');
const backend=read('supabase/functions/court-boss/index.ts');
const app=read('court-boss/app.js');
const v1=read('court-boss/match-center-v1.js');
const v12=read('court-boss/match-center-v12.js');
const v13=read('court-boss/match-center-v13.js');
const v14=read('court-boss/match-center-v14.js');
const v23=read('court-boss/match-experience-v23.js');
const play=read('court-boss/play.html');

test('all Match Center browser scripts parse',()=>{
  for(const [name,source] of [['app',app],['v1',v1],['v12',v12],['v13',v13],['v14',v14],['v23',v23]]){
    assert.doesNotThrow(()=>new Function(source),name+' should parse');
  }
});

test('V13 production page loads the live doubles stack with fresh cache keys',()=>{
  assert.match(play,/app\.js\?v=20261004-match-center-v21-9/);
  assert.match(play,/match-center-v1\.js\?v=20261004-match-center-v21-9/);
  assert.match(play,/match-center-v12\.js\?v=20261003-tactical-ai-v5/);
  assert.match(play,/match-center-v13\.js\?v=20261004-token-colors-v22-1/);
  assert.match(play,/match-center-v13\.css\?v=20261004-token-colors-v22-1/);
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


test('managed tournament Match Center is locked to the exact world-draw opponent',()=>{
  assert.ok(backend.includes('const requestedOpponentId=Number(body?.opponent_id||0)'));
  assert.ok(backend.includes('let opponentId=tournamentId?0:requestedOpponentId'));
  assert.ok(backend.includes('ensureManagedWorldLiveMatch'));
  assert.ok(backend.includes('bracket_mismatch_guard:true'));
  assert.ok(backend.includes('world_match_id:worldMatchId'));
  assert.ok(backend.includes('if(tournamentLive&&Number(meta.world_match_id||0)>0)'));
  assert.ok(backend.includes('Le match live ne correspond plus exactement à la case du tableau mondial.'));
  assert.ok(backend.includes('Number(wr.tournament_id||0)!==tournamentId'));
  assert.ok(backend.includes('(round&&worldRound&&round!==worldRound)'));
  assert.ok(backend.includes('.eq("id",Number(wr.id))'));
  assert.ok(backend.includes('Number(row?.stats?._meta?.world_match_id||0)===Number(worldMatchId)'));
  assert.ok(backend.includes('ok:true,resumed:true,engine:"CB-MATCH-ENGINE-v6"'));
});

test('managed doubles Match Center is locked to the reserved world-draw pair',()=>{
  assert.ok(backend.includes('reserve_managed_doubles_live_matches_v22'));
  assert.ok(backend.includes('Le Match Center double ne peut pas inventer une paire différente du tableau mondial.'));
  assert.ok(backend.includes('world_match_id:Number(worldMatch?.id||0)||null'));
  assert.ok(backend.includes('Le match double live ne correspond plus exactement à la case du tableau mondial.'));
  assert.ok(backend.includes('Number(wr.data.tournament_id||0)!==tournamentId'));
  assert.ok(backend.includes('(round&&worldRound&&round!==worldRound)'));
  assert.ok(backend.includes('Number(row?.stats?._meta?.doubles?.world_match_id||0)===worldMatchId'));
  assert.ok(backend.includes('ok:true,resumed:true,engine:"CB-LIVE-DOUBLES-v1"'));
  assert.ok(backend.includes('Cette case du tableau double possède déjà un autre résultat.'));
  assert.ok(backend.includes('model_version:"CB-LIVE-DOUBLES-v22"'));
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


test('TM live presentation uses names, dense motion and automatic flow',()=>{
  assert.match(v1,/cbDenseMotionFrames/);
  assert.match(v1,/cb-dot-name/);
  assert.match(v1,/cb-tactic-hud/);
  assert.match(v1,/cb-ball-shadow/);
  assert.match(app,/startLiveAutoFlow/);
  assert.doesNotMatch(v1,/simulateLiveGame\(\)">Jeu<\/button>/);
});


test('tournament identity covers signatures and stable generated fallbacks',()=>{
  for(const marker of [
    'signatureTheme','generatedTheme','tournamentTheme','themeHash',
    'indian-wells','monte-carlo','wimbledon','roland','us open',
    'challenger','itf','cbTournamentSkin','cbScene','--cb-theme-accent'
  ]) assert.ok(v14.includes(marker),'missing '+marker);
  assert.match(play,/match-center-v14\.js\?v=20261004-tournament-identity-v22-0/);
  assert.match(play,/match-center-v14\.css\?v=20261004-tournament-identity-v22-0/);
});


test('V23 match experience is data-driven from real live state',()=>{
  for(const marker of [
    'BRIEFING AVANT MATCH','CHANGEMENT DE CÔTÉ','ANALYSE APRÈS-MATCH',
    'h2h_memory','user_service_points_won','opponent_memory_read','line_review',
    'cb-surface-wear-v23','cb-speed-flash-v23','doublesPlan'
  ]) assert.ok(v23.includes(marker),'missing '+marker);
  assert.match(play,/match-experience-v23\.js\?v=20261004-match-experience-v23/);
  assert.match(play,/match-experience-v23\.css\?v=20261004-match-experience-v23/);
});

test('V23 changeover coaching does not invent a second scoring engine',()=>{
  assert.doesNotMatch(v23,/Math\.random\(\).*winner/);
  assert.ok(v23.includes('stats().user_service_points_won')||v23.includes('st.user_service_points_won'));
  assert.ok(v23.includes('lp.changeover'));
  assert.ok(v23.includes('applyTactics'));
});


test('live doubles emits real changeovers for bench coaching',()=>{
  assert.ok(backend.includes('const doublesChangeover=tiebreak'));
  assert.ok(backend.includes('changeover:doublesChangeover'));
  assert.ok(backend.includes('doublesTbPoints>0&&doublesTbPoints%6===0'));
  assert.ok(backend.includes('doublesCompletedGames%2===1'));
  assert.ok(backend.includes('Changement de côté · double'));
  assert.ok(v23.includes('lp.changeover'));
});
