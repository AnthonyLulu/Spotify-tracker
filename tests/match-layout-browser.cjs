/* Offline browser smoke test for Court Boss Match Center FM V2.
 * No game backend, network calls, or production save data is used. */
const {chromium}=require("playwright");
const fs=require("node:fs");
const path=require("node:path");
const assert=require("node:assert/strict");

const root=path.resolve(__dirname,"..");
const read=relative=>fs.readFileSync(path.join(root,relative),"utf8");
const styles=[
 "court-boss/app.css",
 "court-boss/match-center-v1.css",
 "court-boss/match-center-v12.css",
 "court-boss/match-center-v13.css",
 "court-boss/match-center-v14.css",
 "court-boss/match-experience-v23.css",
 "court-boss/match-center-layout-v2.css"
].map(read).join("\n");
const script=read("court-boss/match-center-layout-v2.js");
const marker=id=>'<div data-test="'+id+'"></div>';
function liveCard(){
 const eventRows=Array.from({length:6},(_,i)=>'<div class="cb-event-line"><span>POINT</span><b>Coup gagnant ('+(i+1)+')</b><small>7 coups</small></div>').join("");
 const stats=Array.from({length:10},(_,i)=>'<div><span>Stat '+i+'</span><b>64% - 59%</b></div>').join("");
 return \`<div class="cb-match-shell">
  <div class="card cb-live-card">
   <div class="cb-broadcast-head"><div class="cb-broadcast-brand"><div><small>ATP MASTERS 1000</small><b>Monte-Carlo</b><em>Quart de finale</em></div></div><div class="cb-broadcast-status"><b>LIVE</b></div></div>
   <div class="cb-tv-score"><div class="cb-tv-score-row cb-tv-score-head"><span>JOUEUR</span><span>S1</span><span>S2</span><span>S3</span><span>JEU</span><span>PT</span></div><div class="cb-tv-score-row user"><div class="cb-tv-player">Arthur Fils</div><b>6</b><b>4</b><b>2</b><b>3</b><b>30</b></div></div>
   <div class="cb-match-context"><span>Arthur au service</span><span>Terre battue • Outdoor</span></div>
   <div class="fm-court clay cb-court"><i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i><i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i><i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i><i class="fm-net"></i><div class="fm-player-dot opponent cb-dot" style="left:52%;top:21%"><span>CA</span></div><div class="fm-player-dot user cb-dot" style="left:48%;top:76%"><span>AF</span></div><i class="fm-ball" style="left:50%;top:54%"></i></div>
   <div class="cb-ai-read-v12 card">Lecture de l'IA adverse</div>
   <div class="cb-tactical-lab-v13 card">Laboratoire tactique</div>
   <div class="cb-match-story"><div class="cb-point-story"><div><b>Dernier point</b><small>Revers gagnant</small></div></div><div class="cb-event-feed">\${eventRows}</div></div>
   <div class="fm-momentum">Momentum du match</div>
   <div class="cb-stat-grid">\${stats}</div>
   <div class="cb-live-controls"><div class="cb-speed-row"><button id="pause" type="button">Pause</button><button>1x</button><button>2x</button><button>3x</button></div></div>
   <details class="cb-coach-panel" open><summary>Consignes manager</summary><div class="cb-coach-grid"><label>Risque<select><option>Équilibré</option></select></label><label>Agressivité<input type="range"></label><label>Cibler le revers<input type="checkbox" checked></label></div></details>
  </div></div>\`;
}
function fixture(){
 return '<div class="app-shell"><header class="topbar"><b class="logo">Court Boss</b><span>MANAGER UNIVERSE</span></header><div class="bottom-nav"><button>Accueil</button><button class="active">Match</button><button>Tournois</button><button>Classements</button></div><main class="page" id="main"><div id="app">'+liveCard()+'</div></main></div>';
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
 try{
  for(const [name,width,height] of [["desktop",1600,900],["tablet",1024,768],["phone",390,844]]){
    const page=await browser.newPage({viewport:{width,height}});
    const errors=[];
    page.on("pageerror",e=>errors.push(e.message));
    await page.setContent('<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>'+fixture()+'</body></html>');
    await page.addStyleTag({content:styles});
    await page.addScriptTag({content:script});
    await page.waitForSelector(".cb-layout-switch-v2");
    const sample=async()=>page.evaluate(()=>{
       const rect=q=>{const b=document.querySelector(q).getBoundingClientRect();return {left:b.left,right:b.right,top:b.top,bottom:b.bottom,width:b.width,height:b.height}};
       return {layout:document.documentElement.classList.contains("cb-match-layout-v2"),
         viewport:window.innerWidth,bodyWidth:document.body.scrollWidth,
         court:rect(".cb-court"),story:rect(".cb-match-story"),coach:rect(".cb-coach-panel"),
         stats:rect(".cb-stat-grid"),controls:rect(".cb-live-controls"),
         button:rect(".cb-layout-switch-v2"),buttonText:document.querySelector(".cb-layout-switch-v2").textContent,
         coachDisplay:getComputedStyle(document.querySelector(".cb-coach-panel")).display};
    });
    let state=await sample();
    assert.equal(state.layout,true,name+": V2 layout not enabled");
    assert.ok(state.court.height>=300,name+": court too small");
    assert.ok(state.bodyWidth<=state.viewport+8,name+": horizontal overflow "+JSON.stringify(state));
    if(width>=1200){
      assert.ok(state.story.right<=state.court.left+5,name+": commentary not left");
      assert.ok(state.court.right<=state.coach.left+5,name+": tactics not right");
    }else if(width<920){
      assert.ok(state.court.bottom<=state.story.top+5,name+": mobile court/story stacking");
      assert.ok(state.story.bottom<=state.coach.top+5,name+": mobile story/coach stacking");
    }
    const switcher=page.locator(".cb-layout-switch-v2");
    await switcher.click();
    assert.equal(await page.evaluate(()=>document.documentElement.classList.contains("cb-match-layout-v2")),false,name+": classic toggle failed");
    await switcher.click();
    assert.equal(await page.evaluate(()=>document.documentElement.classList.contains("cb-match-layout-v2")),true,name+": restored toggle failed");
    assert.equal(await page.locator("#pause").count(),1,name+": match controls missing");
    assert.equal(await page.locator(".fm-player-dot").count(),2,name+": player markers missing");
    assert.equal(await page.locator(".fm-ball").count(),1,name+": ball missing");
    // Simulate a match render: the screen is replaced without reloading the app.
    await page.evaluate(html=>{document.querySelector("#app").innerHTML=html},liveCard());
    await page.waitForSelector(".cb-layout-switch-v2");
    assert.equal(await page.locator(".cb-layout-switch-v2").count(),1,name+": switch duplicated after render");
    assert.equal(await page.locator(".cb-coach-panel select").count(),1,name+": tactics unexpectedly removed");
    await page.screenshot({path:path.join(process.cwd(),"match-layout-"+name+".png"),fullPage:true});
    assert.deepEqual(errors,[],name+": JS errors");
    console.log("PASS",name,JSON.stringify(state));
    await page.close();
  }
  // Explicit safety rollback using ?match-ui=classic.
  const page=await browser.newPage();
  await page.goto("about:blank?match-ui=classic");
  await page.setContent('<html><body>'+fixture()+'</body></html>');
  await page.addScriptTag({content:script});
  assert.equal(await page.evaluate(()=>document.documentElement.classList.contains("cb-match-layout-v2")),false,"query rollback failed");
  await page.close();
  console.log("FM MATCH UI BROWSER SMOKE: PASS");
 }finally{
   await browser.close();
 }
})().catch(e=>{console.error(e);process.exitCode=1});
