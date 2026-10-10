/* Browser smoke for the actual V6 presentation layer and tactic callbacks. */
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const load=rel=>fs.readFileSync(path.join(root,rel),'utf8');
const css=['app.css','match-center-v1.css','match-center-v14.css','match-center-layout-v2.css',
'match-center-tournament-v3.css','match-center-arena-v4.css','match-center-perspective-v5.css',
'match-center-experience-v6.css','match-center-mobile-v7.css'].map(f=>load('court-boss/'+f)).join('\n');
const scripts=['match-center-tournament-v3.js','match-center-arena-v4.js',
'match-center-perspective-v5.js','match-center-experience-v6.js','match-center-mobile-v7.js'].map(f=>load('court-boss/'+f));
const events=[
 {id:'ao',name:'Australian Open',city:'Melbourne',surface:'hard',tier:'slam',colorA:'#2f86c9',colorB:'#1f5d95'},
 {id:'rg',name:'Roland-Garros',city:'Paris',surface:'clay',tier:'slam',colorA:'#cf7948',colorB:'#a64f2f'},
 {id:'wimbledon',name:'Wimbledon',city:'Londres',surface:'grass',tier:'slam',colorA:'#69934f',colorB:'#416d36'},
 {id:'uso',name:'US Open',city:'New York',surface:'hard',tier:'slam',colorA:'#315f9e',colorB:'#23477f'},
 {id:'monte-carlo',name:'Monte-Carlo',city:'Monte-Carlo',surface:'clay',tier:'premium',colorA:'#c56f46',colorB:'#9f4d32'},
 {id:'event-22',name:'Lyon Challenger',city:'Lyon',surface:'hard',tier:'challenger',colorA:'#326f98',colorB:'#244f74'},
 {id:'event-44',name:'M25 Antalya',city:'Antalya',surface:'clay',tier:'itf',colorA:'#c67648',colorB:'#9d4c31'}
];
const courtLines=['baseline top','baseline bottom','sideline left','sideline right',
'service horizontal top','service horizontal bottom','service vertical']
.map(x=>'<i class="fm-court-line '+x+'"></i>').join('');
function fixture(f){
 const theme='--cb-theme-court-a:'+f.colorA+';--cb-theme-court-b:'+f.colorB+';--cb-theme-accent:#71caff;--cb-theme-board:#133654';
 return '<div class="app-shell"><div class="topbar">COURT BOSS</div><main class="page"><div id="app"><div class="cb-match-shell"><div class="card fm-live-match cb-live-card" style="'+theme+'">'
  +'<div class="cb-broadcast-head"><div class="cb-broadcast-brand"><div class="cb-broadcast-logo-fallback">'+f.id.toUpperCase()+'</div><div><small>'+f.tier+'</small><b>'+f.name+'</b><em>'+f.city+'</em></div></div></div>'
  +'<div class="cb-tv-score" style="--cb-set-count:2"><div class="cb-tv-score-row cb-tv-score-head"><span>JOUEUR</span><span>S1</span><span>S2</span><span>JEU</span><span>PT</span></div><div class="cb-tv-score-row user"><div class="cb-tv-player">Arthur Fils</div><b>6</b><b>4</b><b>3</b><strong class="cb-tv-point">30</strong></div><div class="cb-tv-score-row opponent"><div class="cb-tv-player">Jannik Sinner</div><b>4</b><b>6</b><b>2</b><strong class="cb-tv-point">15</strong></div></div>'
  +'<div class="cb-match-context"><span>'+({grass:'Gazon',clay:'Terre battue',hard:'Dur'}[f.surface])+' • Outdoor</span></div>'
  +'<div class="fm-court cb-court '+f.surface+'" data-cb-tournament-skin="'+f.id+'" data-cb-venue-tier="'+f.tier+'" style="'+theme+'"><div class="cb-venue-board-v14"><b>'+f.name+'</b></div>'+courtLines+'<i class="fm-net"></i><div class="fm-player-dot user" style="left:48%;top:76%">AF</div><div class="fm-player-dot opponent" style="left:52%;top:21%">JS</div><i class="fm-ball" style="left:48%;top:54%"></i></div>'
  +'<div class="cb-match-story"><div class="cb-event-feed"><div class="cb-event-line"><b>Coup droit gagnant</b></div><div class="cb-event-line"><b>Échange de 14 coups</b></div></div></div>'
  +'<div class="cb-live-controls">Pause • 1x • 2x • 3x</div>'
  +'<details open class="cb-coach-panel"><summary>Consignes manager</summary>'
  +'<div class="cb-plan-strip"><button type="button" class="cb-plan-btn active" data-plan="balanced">Équilibré</button><button type="button" class="cb-plan-btn" data-plan="pressure">Mettre la pression</button></div>'
  +'<div class="cb-coach-grid"><div class="cb-coach-slider"><div><span>Agressivité</span><b>58%</b></div><input type="range" value="58" min="1" max="100"></div>'
  +'<div class="cb-coach-slider"><div><span>Risque</span><b>52%</b></div><input type="range" value="52" min="1" max="100"></div><label>Côté ciblé<select><option>Mixte</option><option>Revers</option><option>Coup droit</option></select></label></div></details>'
  +'<div class="cb-stat-grid"><div><span>Premières balles</span><b>68%</b></div><div><span>ACES</span><b>6</b></div></div>'
  +'</div></div></div></main></div>';
}
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
   for(const [label,width,height] of [['desktop',1530,900],['phone',390,844]]){
     const page=await browser.newPage({viewport:{width,height}});
     const errors=[];page.on('pageerror',err=>errors.push(err.message));
     for(const f of events){
       await page.setContent('<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>'+fixture(f)+'</body></html>');
       await page.addStyleTag({content:css});
       await page.evaluate(f=>{
         window.local={liveMatch:{stats:{_meta:{surface:f.surface,tournament:{name:f.name,city:f.city,category:f.tier,venue:'Court central'}}}},
           tactics:{targetWing:'Mixte',aggression:58,risk:52}};
         window.tournamentLogoHtml=t=>'<span class="tm-tour-logo-fallback"><b>'+t.name+'</b></span>';
         window.cbSetMatchTactic=(key,value)=>{local.tactics[key]=value;};
         window.cbApplyMatchPlan=key=>{local.lastMatchPlan=key};
         document.documentElement.classList.add('cb-match-layout-v2');
       },f);
       // Each renderer is installed only once per page, as in production;
       // later fixture changes are handled through DOM reconciliation.
       if(f===events[0]){
         for(const source of scripts)await page.addScriptTag({content:source});
       }else{
         await page.evaluate(()=>{
           window.cbTournamentPresentationV3.enhance();
           window.cbMatchArenaV4.enhance();
           window.cbCourtPerspectiveV5.enhance();
           window.cbMatchExperienceV6.enhance();
           window.cbMatchMobileV7.enhance();
         });
       }
       await page.locator('.cb-v6-stadium-svg').waitFor({state:'attached'});
       await page.locator('.cb-v6-tactic-chip').first().waitFor({state:'attached'});
       await page.locator('.cb-v7-choice-row').first().waitFor({state:'attached'});
       // Grand Slams may display five set columns. No horizontal scroll
       // must be needed to see the current game's live point score on iPhone.
       if(label==='phone' && f.id==='wimbledon'){
         await page.evaluate(()=>{
           const score=document.querySelector('.cb-tv-score');
           score.style.setProperty('--cb-set-count','5');
           const rows=[...score.querySelectorAll('.cb-tv-score-row')];
           rows.forEach((row,idx)=>{
             const game=row.children[row.children.length-2];
             for(let n=3;n<=5;n++){
               const extra=document.createElement(idx===0?'span':'b');
               if(idx>0)extra.className='cb-tv-set';
               extra.textContent=idx===0?'S'+n:'0';
               row.insertBefore(extra,game);
             }
           });
         });
       }
       const state=await page.evaluate(()=>{
         const c=document.querySelector('.cb-court'),panel=document.querySelector('.cb-coach-panel');
         return {crowd:c.querySelectorAll('.cb-v6-spectators circle').length,
           stadiums:c.querySelectorAll('.cb-v6-stadium-svg').length,planes:c.querySelectorAll('.cb-v5-playing-plane').length,
           projectedDots:c.querySelectorAll('.cb-v5-playing-plane .fm-player-dot').length,
           ball:!!c.querySelector('.cb-v5-playing-plane .fm-ball'),
           boards:[...c.querySelectorAll('.cb-v4-led')].map(n=>n.textContent),
           tacticalButtons:panel.querySelectorAll('.cb-v6-tactic-chip').length,
           tacticsMaps:panel.querySelectorAll('.cb-v6-court-map').length,
           selects:panel.querySelectorAll('select').length,
           v7TacticGroups:panel.querySelectorAll('.cb-v7-choice-row').length,
           bodyWidth:document.documentElement.scrollWidth,viewport:window.innerWidth};
       });
       assert.ok(state.crowd >= (f.tier==='itf'?30:100),'crowd missing for '+f.name);
       assert.equal(state.stadiums,1,'stadium duplicated');
       assert.equal(state.planes,1);
       assert.equal(state.projectedDots,2);
       assert.equal(state.ball,true);
       assert.ok(state.boards.some(x=>x.toUpperCase().includes(f.name.toUpperCase())));
       assert.equal(state.tacticalButtons,3);
       assert.equal(state.v7TacticGroups,3,'live grouped tactics missing');
       assert.equal(state.tacticsMaps,1);
       assert.equal(state.selects,1,'real manager controls removed');
       assert.ok(state.bodyWidth<=state.viewport+8,'unexpected horizontal overflow');
       if(label==='phone'){
         const positions=await page.evaluate(()=>{
           const pos=sel=>document.querySelector(sel).getBoundingClientRect();
           return {court:pos('.cb-court'),coach:pos('.cb-coach-panel'),controls:pos('.cb-live-controls'),
             story:pos('.cb-match-story'),score:pos('.cb-tv-score'),
             point:pos('.cb-tv-score-row.user .cb-tv-point'),
             button:pos('.cb-v7-expand')};
         });
         assert.ok(positions.coach.top>=positions.court.bottom-4 &&
           positions.coach.top<=positions.court.bottom+28,'manager tactics not immediately below court');
         assert.ok(positions.controls.top>=positions.coach.bottom-5,'controls not below coaching');
         assert.ok(positions.story.top>=positions.controls.bottom-4,'comments should follow playback');
         assert.ok(positions.point.right<=positions.score.right+1,'current point obscured on iPhone');
         assert.equal(await page.locator('.cb-coach-grid').isVisible(),false,'advanced inputs should start collapsed');
         await page.locator('.cb-v7-expand').click();
         assert.equal(await page.locator('.cb-coach-grid').isVisible(),true,'advanced inputs inaccessible');
         await page.locator('.cb-v7-expand').click();
       }
       if(['ao','rg','wimbledon','uso','monte-carlo'].includes(f.id))
         await page.screenshot({path:'stadium-v7-'+label+'-'+f.id+'.png',fullPage:false});
       // Verify the action actually enters the game's tactic setter.
       await page.locator('.cb-v6-tactic-chip[data-cb-tactic-value="Revers"]').click();
       assert.equal(await page.evaluate(()=>local.tactics.targetWing),'Revers');
       await page.locator('.cb-v6-tactic-chip[data-cb-tactic-value="Mixte"]').click();
       assert.equal(await page.evaluate(()=>local.tactics.targetWing),'Mixte');
       await page.locator('.cb-v7-choice-row[data-tactic="aggression"] .cb-v7-choice').last().click();
       assert.equal(await page.evaluate(()=>local.tactics.aggression),78,'aggression shortcut not using match engine');
       await page.locator('.cb-v7-choice-row[data-tactic="tempo"] .cb-v7-choice').last().click();
       assert.equal(await page.evaluate(()=>local.tactics.tempo),'Rapide','tempo shortcut not using match engine');
       await page.locator('.cb-v7-choice-row[data-tactic="effort"] .cb-v7-choice').first().click();
       assert.equal(await page.evaluate(()=>local.tactics.effort),45,'effort shortcut not using match engine');
       await page.locator('.cb-plan-btn[data-plan="pressure"]').evaluate(el=>{window.cbApplyMatchPlan(el.dataset.plan)});
       assert.equal(await page.evaluate(()=>local.lastMatchPlan),'pressure');
       await page.evaluate(()=>{window.cbMatchExperienceV6.enhance();window.cbMatchMobileV7.enhance()});
       assert.equal(await page.locator('.cb-v6-stadium-svg').count(),1);
       assert.equal(await page.locator('.cb-v6-tactic-quick').count(),1);
       assert.equal(await page.locator('.cb-v7-mobile-tactics').count(),1,'V7 groups duplicated');
       assert.deepEqual(errors,[]);
       console.log('PASS',label,f.name,'spectators',state.crowd);
     }
     await page.close();
   }
   console.log('V7 RESPONSIVE TACTICS, SCORE AND STADIUM: PASS');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});