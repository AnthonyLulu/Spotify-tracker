import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
import { juniorTournamentFormatRule, projectedTournamentCuts, qualifyingSectionPlan, tournamentDoublesDrawConfig, tournamentRoundPrize } from '../supabase/functions/court-boss/tournament-policy.ts';

const source=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8').replace(/\ninit\(\);\s*$/,'');
function frontend(){
 const alerts=[],requests=[];
 const nodes=new Map();
 const ctx=vm.createContext({console,URL,URLSearchParams,Intl,Date,crypto,structuredClone,setTimeout,clearTimeout,setInterval,clearInterval,window:{},document:{getElementById:id=>{if(!nodes.has(id))nodes.set(id,{innerHTML:'',style:{}});return nodes.get(id)},addEventListener(){}},localStorage:{getItem:()=>null,setItem(){},removeItem(){}},alert:m=>alerts.push(m),confirm:()=>true,prompt:()=>'',fetch:async url=>{requests.push(url);return {ok:true,status:200,json:async()=>ctx.response}}});
 vm.runInContext(source,ctx);
 vm.runInContext("boot={upcoming:[],career:{}};local.career={singles_rank:300,country:'FRA',age:22,managed_player_id:1};render=()=>{};persist=()=>{};",ctx);
 return {ctx,alerts,requests,run:code=>vm.runInContext(code,ctx),html:()=>nodes.get('overlay').innerHTML};
}

test('Official ITF qualifying pays zero; explicit zero never triggers an invented prize',()=>{
 const t={prize_money:15000,qualifying_prize_is_estimate:false,qualifying_prize_by_result:{}};
 assert.equal(tournamentRoundPrize(t,'Q1','qualifying').amount,0);
 assert.equal(tournamentRoundPrize({...t,qualifying_prize_by_result:{Q2:0}},'Q2','qualifying').amount,0);
 assert.equal(tournamentRoundPrize({...t,qualifying_prize_is_estimate:true,qualifying_prize_by_result:{Q2:0}},'Q2','qualifying').amount,0);
});
test('Non-power-of-two draws resolve prize aliases and retain cents',()=>{
 assert.equal(tournamentRoundPrize({singles_prize_by_result:{R64:140.40},singles_prize_is_estimate:false},'R48').amount,140.4);
 assert.equal(tournamentRoundPrize({singles_prize_by_result:{W:2160}},'Champion').amount,2160);
 assert.equal(tournamentRoundPrize({doubles_prize_by_result:{R32:400}},'R24','doubles').amount,400);
});
test('Only genuinely missing estimated tables can use the explicit estimate',()=>{
 assert.equal(tournamentRoundPrize({prize_money:100000,singles_prize_is_estimate:true},'W').amount,18000);
 assert.equal(tournamentRoundPrize({prize_money:100000,singles_prize_by_result:{W:18000}},'R16').amount,0);
 assert.equal(tournamentRoundPrize({prize_money:100000},'Non joué').amount,0);
});
test('A Top 200 player cannot enter an M15 or receive an M15 wildcard',()=>{
 const f=frontend();f.run("local.career.singles_rank=2;t={circuit:'ITF',category:'M15',direct_cut:600,qual_cut:1000};");
 assert.equal(f.run('singlesEligibility(t).can'),false);
 assert.equal(f.run('singlesEligibility(t).canWildcard'),false);
 f.run('local.career.singles_rank=201');assert.equal(f.run('singlesEligibility(t).can'),true);
});
test('Challenger play-down boundaries and host-country WC restrictions are respected',()=>{
 const f=frontend();f.run("t={circuit:'Challenger',category:'Challenger 50',country:'GBR',direct_cut:500,qual_cut:1000};local.career.singles_rank=50");
 assert.equal(f.run('singlesEligibility(t).canWildcard'),false);
 f.run('local.career.singles_rank=51');assert.equal(f.run('singlesEligibility(t).canWildcard'),false);
 f.run("t.country='FRA'");assert.equal(f.run('singlesEligibility(t).canWildcard'),true);
 f.run('local.career.singles_rank=150');assert.equal(f.run('singlesEligibility(t).can'),false);
 f.run('local.career.singles_rank=151');assert.equal(f.run('singlesEligibility(t).can'),true);
 f.run("t.category='Challenger 100';local.career.singles_rank=20");assert.equal(f.run('singlesEligibility(t).canWildcard'),true);
 f.run("t.category='Challenger 75'");assert.equal(f.run('singlesEligibility(t).canWildcard'),false);
});
test('Server deadline ranking overrides the projected rank, without leaking to a new date',()=>{
 const f=frontend();f.run("t={circuit:'ITF',category:'M15',direct_cut:600,entry_rule_context:tournamentEntryContext(),managed_entry_rules:{direct:{eligible:false,reason:'itf_play_down_top200'},wildcard:{eligible:false}}}");
 assert.equal(f.run('singlesEligibility(t).can'),false);
 f.run("local.date='2025-12-08'");assert.equal(f.run('singlesEligibility(t).can'),true);
});
test('Qualification window starts before the main draw and uses its own entry deadline',()=>{
 const f=frontend();f.run("t={start_date:'2026-08-31',main_draw_start_date:'2026-08-31',end_date:'2026-09-13',qualifying_start_date:'2026-08-24',qualifying_entry_deadline:'2026-08-05',singles_entry_deadline:'2026-07-20'}");
 assert.equal(f.run("tournamentParticipationWindow(t,{method:'qualifying'}).start_date"),'2026-08-24');
 assert.equal(f.run("tournamentParticipationWindow(t,{method:'qualifying'}).deadline"),'2026-08-05');
 assert.equal(f.run("tournamentParticipationWindow(t,{method:'direct'}).start_date"),'2026-08-31');
});
test('Enrollment rejects a tournament overlapping qualifying in the previous week',async()=>{
 const f=frontend();f.run("tourRows=[{id:7,circuit:'ATP',category:'ATP 250',name:'Next event',start_date:'2026-08-31',end_date:'2026-09-06',qualifying_start_date:'2026-08-29',qualifying_entry_deadline:'2026-08-20',direct_cut:100,qual_cut:400}];local.entryMeta={6:{name:'Previous event',start_date:'2026-08-24',end_date:'2026-08-30'}}");
 f.ctx.response={tournament:f.run('tourRows[0]'),entry_rules:{qualifying:{eligible:true},wildcard:{eligible:true}}};
 await f.run('window.toggleSinglesEntry(7)');
 assert.match(f.alerts[0],/Conflit calendrier/);assert.equal(f.run('local.entries.length'),0);
 assert.match(f.requests[0],/tournament-entry-status/);
});
test('Enrollment after singles deadline remains possible before the qualifying deadline',async()=>{
 const f=frontend();f.run("local.date='2026-08-01';tourRows=[{id:7,circuit:'ATP',category:'ATP 250',name:'Next event',start_date:'2026-08-31',end_date:'2026-09-06',qualifying_start_date:'2026-08-29',singles_entry_deadline:'2026-07-20',qualifying_entry_deadline:'2026-08-05',direct_cut:100,qual_cut:400}]");
 f.ctx.response={tournament:f.run('tourRows[0]'),entry_rules:{qualifying:{eligible:true}}};
 await f.run('window.toggleSinglesEntry(7)');assert.equal(f.alerts.length,0);assert.equal(f.run('local.entryMeta[7].entry_start_date'),'2026-08-29');
});
test('Calendar renders the qualifying deadline and dates without runtime errors',()=>{
 const f=frontend();const html=f.run("tournamentTmRow({id:7,name:'Test',circuit:'ATP',category:'ATP 250',start_date:'2026-08-31',end_date:'2026-09-06',qualifying_start_date:'2026-08-29',direct_cut:100,qual_cut:400})");
 assert.match(html,/Qualifs dès le/);
});
test('128-player draw is complete; qualifier placeholders are not clickable',()=>{
 const f=frontend();const html=f.run("tournamentEntryRowsHtml([...Array.from({length:112},(_,i)=>({id:i+1,name:'Player '+i,ranking:i+1})),...Array.from({length:16},(_,i)=>({id:null,name:'Qualifier '+i,entry_method:'qualifier_slot'}))])");
 assert.equal((html.match(/<tr /g)||[]).length,128);assert.equal((html.match(/onclick=/g)||[]).length,112);assert.doesNotMatch(html,/openPlayer\(null\)/);
});
test('Winston-Salem exposes 48 entrants, 16 byes and two qualifying rounds',()=>{
 const f=frontend();const html=f.run("tournamentFormatHtml({format_type:'knockout',main_draw_size:48,bracket_size:64,seed_count:16,qualifier_count:4,qualifying_draw_size:16,rounds:['R48','R32','R16','QF','SF','F']},{singles_draw_size:48})");
 assert.match(html,/48 joueurs · 6 tours/);assert.match(html,/16 exemptions/);assert.match(html,/16 matchs au premier tour/);assert.match(html,/2 tours · 4 places/);
});
test('Official total does not mislabel unknown or estimated phase payouts',()=>{
 const f=frontend();const html=f.run("tournamentEconomicsHtml({total:818240,total_is_estimate:false,singles:{W:112420},singles_is_estimate:false,qualifying:{},qualifying_is_estimate:true,doubles:{W:40000},doubles_is_estimate:true},{doubles:true,start_date:'2026-08-23'})");
 assert.match(html,/Total officiel/);assert.match(html,/Barème officiel/);assert.match(html,/Gains non renseignés/);assert.match(html,/Barème estimé/);
});
test('Finals display participation and cumulative round-robin bonuses',()=>{
 const f=frontend();const html=f.run("tournamentEconomicsHtml({format:'round_robin_components',special:{singles:{PARTICIPATION:100,RR_WIN:200,SF_WIN:300,F_WIN:400}}},{start_date:'2026-11-01'})");
 assert.match(html,/Participation/);assert.match(html,/Par victoire en poule/);assert.match(html,/Ces primes se cumulent/);
});

function backend(){
 let handler;const calls=[],writes=[];
 const data={tournaments:{id:7,circuit:'ITF',category:'M15'},career_state:{managed_player_id:1,singles_rank:2,career_focus:'mixed'},wildcard_requests:null,academies:{reputation:100}};
 const db={from(table){const q={select(){return q},eq(){return q},maybeSingle:async()=>({data:data[table]??null,error:null}),upsert(){writes.push(table);throw Error('Unexpected write')}};return q},async rpc(name,args){calls.push({name,args});return {data:{eligible:false,reason:'itf_play_down_top200',entry_method:args.p_entry_method},error:null}}};
 const code=stripTypeScriptTypes(fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8').replace(/^import .*;\n/gm,''));
 vm.runInNewContext(code,{console,URL,Request,Response,Headers,Date,Intl,crypto,TextEncoder,TextDecoder,fetch,createClient:()=>db,tournamentRoundPrize,Deno:{env:{get:()=>''},serve:fn=>{handler=fn}}});
 return {handler,calls,writes};
}
test('Entry API returns authoritative decisions for all supported modes without writes',async()=>{
 const b=backend();const r=await b.handler(new Request('https://example.test/api/tournament-entry-status?id=7'));const result=await r.json();
 assert.equal(r.status,200);
 assert.deepEqual(['direct','qualifying','wildcard','alternate','protected','protected_qualifying'].filter(k=>!Object.hasOwn(result.entry_rules,k)),[]);
 assert.equal(result.entry_rules.player_id,1);assert.equal(result.entry_rules.persisted_entry,null);
 assert.equal(result.entry_rules.wildcard.eligible,false);
 assert.equal(result.entry_rules.protected.entry_method,'protected');
 assert.equal(b.writes.length,0);
});
test('Wildcard request is rejected before saving any decision when the player is ineligible',async()=>{
 const b=backend();const r=await b.handler(new Request('https://example.test/api/manager-action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'request_wildcard',id:7})}));
 assert.equal(r.status,409);assert.equal((await r.json()).entry_rule.reason,'itf_play_down_top200');assert.equal(b.writes.length,0);
});



test('Junior Grand Slam cuts send mid-ranked juniors through qualifying and reject players outside the field',()=>{
 const f=frontend();
 f.run("local.date='2025-12-01';local.career={...local.career,age:17,junior_rank:60,junior_ranking:60};t={circuit:'Junior',category:'Junior Grand Slam',projected_direct_cut:48,projected_qual_cut:80,cut_is_projection:true,singles_entry_deadline:'2025-12-16',qualifying_entry_deadline:'2025-12-16',qualifying_start_date:'2026-01-21'}");
 assert.equal(f.run('singlesEligibility(t).method'),'qualifying');
 assert.equal(f.run('singlesEligibility(t).can'),true);
 f.run('local.career.junior_rank=81;local.career.junior_ranking=81');
 assert.equal(f.run('singlesEligibility(t).can'),false);
 assert.equal(f.run('singlesEligibility(t).canWildcard'),true);
 f.run("local.date='2025-12-17'");
 assert.equal(f.run('singlesEligibility(t).can'),false);
 assert.equal(f.run('singlesEligibility(t).canWildcard'),false);
});

test('Backend Junior Slam path contains real qualifying simulation and host-priority wildcard field',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/structuredJuniorEntry/);
 assert.match(code,/entry_preview_model:"junior_qualifying_v1"/);
 assert.match(code,/qualifyingCandidateIdsForRun=new Set/);
 assert.match(code,/String\(a\.country\|\|""\)===String\(t\.country\|\|""\)/);
 assert.match(code,/entry_method:"wildcard"/);
});

test('Special team events never enter the standard individual tournament flow',()=>{
 const f=frontend();
 f.run("t={category:'United Cup',entry_rule_code:'UNITED_CUP_TEAM',singles:true,doubles:true};local.career.age=22");
 assert.equal(f.run('singlesEligibility(t).can'),false);
 assert.equal(f.run('singlesEligibility(t).phase'),'team_selection');
 assert.equal(f.run('doublesEligibility(t).can'),false);
 assert.equal(f.run('specialTeamEventMeta(t).teams'),18);
 f.run("t={category:'Laver Cup',entry_rule_code:'LAVER_CUP_INVITE',singles:true,doubles:true}");
 assert.equal(f.run('specialTeamEventMeta(t).teams'),2);
 f.run("t={category:'Junior Davis Cup',entry_rule_code:'JUNIOR_DAVIS_SELECTION',circuit:'Junior',singles:true,doubles:true};local.career.age=17");
 assert.equal(f.run('singlesEligibility(t).phase'),'team_selection');
 assert.equal(f.run('specialTeamEventMeta(t).teams'),16);
});

test('Backend exposes team event metadata and blocks standard tournament simulation',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/function specialTeamEventMeta\(t:any\)/);
 assert.match(code,/entry_preview_model:"team_selection_v2_captains"/);
 assert.match(code,/Cette compétition se joue par équipes et par sélection/);
 assert.match(code,/UNITED_CUP_TEAM/);
 assert.match(code,/LAVER_CUP_INVITE/);
 assert.match(code,/JUNIOR_DAVIS_SELECTION/);
});

test('Doubles draw config supports full 64-team Slams and realistic seed counts',()=>{
 assert.deepEqual(tournamentDoublesDrawConfig({singles_draw_size:128,doubles_draw_size:64}),{drawSize:64,seedCount:16});
 assert.deepEqual(tournamentDoublesDrawConfig({singles_draw_size:48,doubles_draw_size:24}),{drawSize:24,seedCount:8});
 assert.deepEqual(tournamentDoublesDrawConfig({singles_draw_size:128}),{drawSize:32,seedCount:8});
});
test('Backend fills a partial active doubles field instead of capping projections at 32',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.doesNotMatch(code,/wanted=Math\.min\(32,drawSize\)/);
 assert.match(code,/doublesMain\.length<doublesDrawSize/);
 assert.match(code,/const pairPoolTarget=Math\.max\(0,drawSize-1\+\(managedDoubleQualifying\?3:0\)\)/);
 assert.match(code,/pairs\.length<pairPoolTarget/);
 assert.match(code,/source:isJuniorDouble\?"junior-ranking-projection":"ranking-projection"/);
});


test('Projected cuts follow the last actually eligible projected entrant',()=>{
 const t=projectedTournamentCuts(
  {direct_cut:null,qual_cut:null,projected_direct_cut:75,projected_qual_cut:165},
  [
   {ranking:12,entry_method:'direct'},
   {ranking:87,entry_method:'direct'},
   {ranking:140,entry_method:'wildcard'},
   {ranking:null,entry_method:'qualifier_slot'}
  ],
  [{ranking:103},{ranking:221},{ranking:190}]
 );
 assert.equal(t.projected_direct_cut,87);
 assert.equal(t.projected_qual_cut,221);
 assert.equal(t.projected_cut_model,'eligible_field_v1');
});
test('Official tournament cuts are never overwritten by the projected field',()=>{
 const t=projectedTournamentCuts(
  {direct_cut:55,qual_cut:120,projected_direct_cut:80,projected_qual_cut:180},
  [{ranking:99,entry_method:'direct'}],
  [{ranking:250}]
 );
 assert.equal(t.projected_direct_cut,80);
 assert.equal(t.projected_qual_cut,180);
});


test('Tournament simulation uses deadline ranking and eligible-field cuts before choosing direct or qualifying',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/entryRankingDate/);
 assert.match(code,/projectedTournamentCuts\(\s*t,/);
 assert.match(code,/qualifyingCandidateIdsForRun/);
 assert.match(code,/entry_projection_model:entryProjectionModel/);
});
test('Tournament result UI keeps the event currency instead of forcing euros',()=>{
 const code=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
 assert.match(code,/money\(d\.user_prize,d\.tournament\?\.prize_currency\|\|'USD'\)/);
 assert.match(code,/money\(d\.prize\|\|0,d\.tournament\?\.prize_currency\|\|'USD'\)/);
});


test('Normal doubles fields prefer documented race teams before synthetic rank pairings',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/projectedDoublesRaceRows/);
 assert.match(code,/doubles_race_2025_full/);
 assert.match(code,/source:"doubles-race-projection"/);
 assert.match(code,/if\(pairs\.length<pairPoolTarget&&projectedRacePairRows\.length\)/);
});

test('Doubles seeding uses race or pair ranking rather than hidden match strength',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/const seedOrder=entrants\.slice\(\)\.sort/);
 assert.match(code,/Number\(a\.entry_rank\|\|999999\)-Number\(c\.entry_rank\|\|999999\)/);
 assert.doesNotMatch(code,/const entrants=\[userPair,\.\.\.pairs\]\.slice\(0,drawSize\)\.sort\(\(a:any,b:any\)=>Number\(b\.strength/);
});


test('Qualifying formats split into independent sections with one main-draw place each',()=>{
 assert.deepEqual(qualifyingSectionPlan(16,4),{drawSize:16,qualifierSlots:4,sectionCount:4,sectionPlayers:4,sectionSize:4,bracketTotal:16,byeCount:0,rounds:2});
 assert.deepEqual(qualifyingSectionPlan(24,6),{drawSize:24,qualifierSlots:6,sectionCount:6,sectionPlayers:4,sectionSize:4,bracketTotal:24,byeCount:0,rounds:2});
 assert.deepEqual(qualifyingSectionPlan(28,7),{drawSize:28,qualifierSlots:7,sectionCount:7,sectionPlayers:4,sectionSize:4,bracketTotal:28,byeCount:0,rounds:2});
 assert.deepEqual(qualifyingSectionPlan(48,12),{drawSize:48,qualifierSlots:12,sectionCount:12,sectionPlayers:4,sectionSize:4,bracketTotal:48,byeCount:0,rounds:2});
 assert.deepEqual(qualifyingSectionPlan(128,16),{drawSize:128,qualifierSlots:16,sectionCount:16,sectionPlayers:8,sectionSize:8,bracketTotal:128,byeCount:0,rounds:3});
});
test('Uneven junior qualifying sections preserve all qualifier places',()=>{
 const j200=qualifyingSectionPlan(32,6);
 assert.deepEqual(j200,{drawSize:32,qualifierSlots:6,sectionCount:6,sectionPlayers:6,sectionSize:8,bracketTotal:48,byeCount:16,rounds:3});
 const orangeBowl=qualifyingSectionPlan(64,8);
 assert.deepEqual(orangeBowl,{drawSize:64,qualifierSlots:8,sectionCount:8,sectionPlayers:8,sectionSize:8,bracketTotal:64,byeCount:0,rounds:3});
});
test('Tournament-specific qualifying size overrides the generic category rule',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.equal(code.split('t.qualifying_draw_size??formatRule?.qualifying_draw_size').length-1,3);
 assert.equal(code.split('formatRule?.qualifying_draw_size??t.qualifying_draw_size').length-1,0);
 assert.match(code,/const juniorDirectSlots=Math\.max\(0,drawSize-Math\.max\(0,Number\(formatRule\?\.qualifier_count\|\|0\)\)-wcSlots\)/);
});

test('Tournament engine simulates the full qualifying field and protects qualifiers from seeding',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/const sections:any\[\]\[\]=Array\.from/);
 assert.match(code,/qualifyingFinalLosers/);
 assert.match(code,/qualifierWinners/);
 assert.match(code,/entry_method:"qualifier"/);
 assert.match(code,/seedEligibleEntrants=rankedEntrants\.filter/);
 assert.match(code,/\["qualifier","lucky_loser"\]/);
});


test('Tournament runs persist the actual entry method for later calendar checks',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/tournament_runs"\)\.insert\(\{\s*tournament_id:tid,managed_player_id:managedId,entry_method:entryMode/);
});

test('Doubles entry status is server authoritative and uses combined best rankings',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/\/api\/doubles-entry-status/);
 assert.match(code,/bestDoublesEntryRank/);
 assert.match(code,/projectedDoublesAcceptanceCut/);
 assert.match(code,/Paire hors de la ligne d’acceptation projetée/);
});

test('Doubles draw composition follows ATP Challenger ITF and Grand Slam slots',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/model:"atp_250_2026"/);
 assert.match(code,/model:"atp_500_2026"/);
 assert.match(code,/model:"masters_1000_2026"/);
 assert.match(code,/const advance=Math\.min\(10,draw\),onsite=/);
 assert.match(code,/return \{draw,direct:advance\+onsite,advance,onsite,wildcards:/);
 assert.match(code,/model:"itf_m25"/);
 assert.match(code,/model:"itf_m15"/);
 assert.match(code,/model:"grand_slam_2026"/);
});

test('Frontend checks doubles entry with server before scheduling and before play',()=>{
 const code=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
 assert.match(code,/window\.toggleDoublesEntry=async id=>/);
 assert.match(code,/\/api\/doubles-entry-status\?id=/);
 assert.match(code,/managed_doubles_entry_status/);
 assert.match(code,/Inscrire la paire avant de jouer/);
});

test('Doubles fields are tier-aware so small events do not reuse elite fields',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/function doublesFieldBand/);
 assert.match(code,/model:"grand_slam"/);
 assert.match(code,/model:"atp_250"/);
 assert.match(code,/model:"challenger_75"/);
 assert.match(code,/model:"itf_m25"/);
 assert.match(code,/model:"itf_m15"/);
 assert.match(code,/projectedDoublesTournamentRows/);
});

test('Doubles acceptance tolerates missing individual rank data with race based estimate',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/const raceEstimate=Math\.max\(1,Math\.round\(raceRank\*2\)\)/);
 assert.match(code,/Math\.min\(aKnown,raceEstimate\)/);
 assert.match(code,/field_band:cut\.band/);
});

test('Live ranking imports cannot overwrite the frozen 2025 baseline',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/refresh-live-rankings/);
 assert.match(code,/refresh-doubles-race/);
 assert.match(code,/refresh-races/);
 assert.match(code,/baseline_snapshot:AGE_REFERENCE_DATE/);
 assert.match(code,/locked:true/);
 assert.doesNotMatch(code,/apply_live_rankings.*p_snapshot:snapshot/s);
});

test('Doubles projection seeds are recomputed from race or combined ranking',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/const seedMetric=\(x:any\)=>/);
 assert.match(code,/const seedOrder=doublesMain\.slice\(\)\.sort/);
 assert.match(code,/const seedMap=new Map/);
 assert.match(code,/for\(const pair of doublesMain\)pair\.seed=seedMap/);
});

test('Player profiles expose simulated prize money for AI and managed careers',()=>{
 const backend=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
 assert.match(backend,/careerFinancials/);
 assert.match(backend,/world_tournament_entries/);
 assert.match(backend,/world_doubles_tournament_entries/);
 assert.match(backend,/prize_awarded\|\|0\)\/2/);
 assert.match(app,/Prize money sauvegarde/);
 assert.match(app,/Économie de carrière simulée/);
});


test('Junior 48-draw fallback follows ITF 2026 composition',()=>{
 const r=juniorTournamentFormatRule({circuit:'Junior',category:'J500',singles_draw_size:48,qualifying_draw_size:48,doubles_draw_size:24,junior_draw_format:'elimination'});
 assert.equal(r.main_draw_size,48);
 assert.equal(r.bracket_size,64);
 assert.equal(r.seed_count,16);
 assert.equal(r.qualifier_count,6);
 assert.equal(r.wildcard_count,6);
 assert.equal(r.qualifying_draw_size,48);
 assert.equal(r.doubles_draw_size,24);
 assert.deepEqual(r.rounds,['R48','R32','R16','QF','SF','F']);
});

test('Junior 64-draw and J30/J60 round-robin composition are distinct',()=>{
 const slam=juniorTournamentFormatRule({circuit:'Junior',category:'Junior Grand Slam',singles_draw_size:64,qualifying_draw_size:32,doubles_draw_size:32,junior_draw_format:'elimination'});
 assert.equal(slam.seed_count,16);
 assert.equal(slam.qualifier_count,8);
 assert.equal(slam.wildcard_count,8);
 const rr=juniorTournamentFormatRule({circuit:'Junior',category:'J60',singles_draw_size:32,qualifying_draw_size:32,doubles_draw_size:16,junior_draw_format:'round_robin_to_elimination'});
 assert.equal(rr.format_type,'round_robin');
 assert.equal(rr.qualifier_count,8);
 assert.equal(rr.wildcard_count,4);
 assert.deepEqual(rr.rounds,['RR','QF','SF','F']);
});



test('Live and quick simulations share the canonical runtime point kernel',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/const livePointKernel=\(ctx:any\)=>/);
 assert.ok((code.match(/livePointKernel\(\{/g)||[]).length>=2);
 assert.match(code,/simulation_granularity:matchTiebreakActive\?"match_tiebreak":tiebreakActive\?"tiebreak":"game"/);
 assert.match(code,/rally_no:Number\(session\.data\.rally_no\|\|0\)\+gamePoints/);
});

test('Match form is a temporary runtime modifier and never a base attribute write',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/mode:"temporary_multiplier_runtime_only"/);
 assert.match(code,/persists_to_player_attributes:false/);
 const liveStart=code.indexOf('if(path.endsWith("/api/live-match/point")');
 const commitStart=code.indexOf('if(path.endsWith("/api/live-match/commit")');
 const liveBlock=code.slice(liveStart,commitStart);
 assert.doesNotMatch(liveBlock,/db\.from\("player_attributes"\)\.update/);
});

test('Legacy live advance cannot mutate career before explicit validation',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 const start=code.indexOf('if(path.endsWith("/api/live-match/advance")');
 const end=code.indexOf('if(path.endsWith("/api/live-match/point")');
 const block=code.slice(start,end);
 assert.match(block,/Endpoint obsolète/);
 assert.match(block,/410/);
 assert.doesNotMatch(block,/players"\)\.update/);
 assert.doesNotMatch(block,/match_history"\)\.insert/);
});

test('Match Center tells the player that form does not rewrite permanent attributes',()=>{
 const ui=fs.readFileSync(new URL('../court-boss/match-center-v1.js',import.meta.url),'utf8');
 assert.match(ui,/La forme est un multiplicateur temporaire de match/);
 assert.match(ui,/aucune note de base n’est réécrite/);
 assert.match(ui,/Même moteur pour le live et la simulation/);
});

test('Backend uses the ITF junior fallback when no explicit format row exists',()=>{
 const code=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 assert.match(code,/juniorFormatRes\.data\|\|juniorTournamentFormatRule\(t\.data\)/);
 assert.match(code,/String\(t\.circuit\|\|""\)===\"Junior\"\?juniorTournamentFormatRule\(t\):null/);
});


test('Medical V15 exposes play-hurt decisions and persistent injury history',()=>{
 const backend=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
 const ui=fs.readFileSync(new URL('../court-boss/medical-v15.js',import.meta.url),'utf8');
 assert.match(backend,/medical_decision/);
 assert.match(backend,/can_play_hurt/);
 assert.match(backend,/playing_hurt/);
 assert.match(backend,/injury_history/);
 assert.match(backend,/player_injury_vulnerabilities/);
 assert.match(backend,/player_injury_recovery_effects/);
 assert.match(ui,/Déclarer forfait/);
 assert.match(ui,/Jouer diminué/);
 assert.match(ui,/Historique, zones fragiles & séquelles/);
});

test('Match Center V14 spectacle layer is wired into the playable client',()=>{
 const html=fs.readFileSync(new URL('../court-boss/play.html',import.meta.url),'utf8');
 const js=fs.readFileSync(new URL('../court-boss/match-center-v14.js',import.meta.url),'utf8');
 assert.match(html,/match-center-v14\.js/);
 assert.match(html,/match-center-v14\.css/);
 assert.match(js,/cb-atmosphere-v14/);
 assert.match(js,/cb-weather-v14/);
 assert.match(js,/cb-medical-scene-v14/);
 assert.match(js,/cb-momentum-v14/);
});
