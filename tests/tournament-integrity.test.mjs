import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
import { tournamentDoublesDrawConfig, tournamentRoundPrize } from '../supabase/functions/court-boss/tournament-policy.ts';

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
test('Entry API returns authoritative decisions for four modes without writes',async()=>{
 const b=backend();const r=await b.handler(new Request('https://example.test/api/tournament-entry-status?id=7'));const result=await r.json();
 assert.equal(r.status,200);assert.equal(Object.keys(result.entry_rules).length,4);assert.equal(result.entry_rules.wildcard.eligible,false);assert.equal(b.writes.length,0);
});
test('Wildcard request is rejected before saving any decision when the player is ineligible',async()=>{
 const b=backend();const r=await b.handler(new Request('https://example.test/api/manager-action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'request_wildcard',id:7})}));
 assert.equal(r.status,409);assert.equal((await r.json()).entry_rule.reason,'itf_play_down_top200');assert.equal(b.writes.length,0);
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
 assert.match(code,/pairs\.length<drawSize-1/);
 assert.match(code,/source:isJuniorDouble\?"junior-ranking-projection":"ranking-projection"/);
});
